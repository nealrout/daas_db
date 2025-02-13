CALL drop_functions_by_name('get_asset');
/
-- Stored procedure to get all items
CREATE OR REPLACE FUNCTION get_asset(p_user_id bigint)
RETURNS TABLE(id BIGINT, fac_code TEXT, asset_nbr TEXT, sys_id TEXT, create_ts timestamptz, update_ts timestamptz) 
AS '
BEGIN
    RETURN QUERY
    SELECT 
		asset.id, facility.fac_code , asset.asset_nbr, asset.sys_id, asset.create_ts, asset.update_ts
	FROM 
		asset asset
    	JOIN facility facility on asset.fac_id = facility.id
		JOIN user_facility uf on facility.id = uf.fac_id
	WHERE 
		(uf.user_id = p_user_id OR p_user_id is null);
END;
' LANGUAGE plpgsql;
/
CALL drop_functions_by_name('get_asset_by_json');
/
-- Stored procedure to get an asset by ID
CREATE OR REPLACE FUNCTION get_asset_by_json(p_jsonb jsonb, p_user_id bigint)
RETURNS TABLE(acct_nbr text, fac_nbr text, asset_nbr text, sys_id text, status_code text, create_ts timestamptz, update_ts timestamptz)
AS '
DECLARE
--	p_jsonb jsonb := ''{
--		"acct_nbr": ["ACCT_NBR_10"],
--        "fac_code": ["US_TEST_10"],
--        "fac_name": ["TEST FACILITY 17", "TEST FACILITY 18"],
--        "fac_nbr": ["FAC_NBR_03", "FAC_NBR_02"]
--    }'';
--
--	p_user_id bigint := 2;
BEGIN
	
	drop table if exists parsed_keys;
	drop table if exists parsed_values;

	create temp table parsed_keys as
	select * from iterate_json_keys(p_jsonb);

	create temp table parsed_values as
	select 
		get_jsonb_values_by_key (json_output, ''acct_nbr'') as acct_nbr, 
		get_jsonb_values_by_key (json_output, ''fac_nbr'') as fac_nbr, 
		get_jsonb_values_by_key (json_output, ''asset_nbr'') as asset_nbr,
		get_jsonb_values_by_key (json_output, ''sys_id'') as sys_id,
		get_jsonb_values_by_key (json_output, ''status_code'') as status_code
	from parsed_keys p;

--	create table res as select acct.acct_nbr, fac.fac_nbr, ass.asset_nbr, ass.sys_id, ass.status_code, ass.create_ts, ass.update_ts
--	from account acct join facility fac on acct.id = fac.acct_id join asset a on fac.id = a.fac_id limit 0;

	RETURN QUERY
	with acct_cte_condition as (
		select acc.*
		from account acc
		join parsed_values v on acc.acct_nbr = v.acct_nbr
	),
	acct_cte_no_condition as (
		select acc.*
		from account acc
	),
	fac_cte_condition as (
		SELECT f.*
		FROM facility f
		JOIN parsed_values v ON f.fac_nbr = v.fac_nbr
	),
	fac_cte_no_condition as (
		select f.*
		from facility f
	),
	asset_cte_condition as (
		select a.*
		from asset a
		join parsed_values v on a.asset_nbr = v.asset_nbr
		union
		select a.*
		from asset a
		join parsed_values v on a.sys_id = v.sys_id
		union
		select a.*
		from asset a
		join parsed_values v on a.status_code = v.status_code
	),
	asset_cte_no_condition as (
		select a.*
		from asset a
	)

--	insert into res
	
	select acct.acct_nbr, fac.fac_nbr, ass.asset_nbr, ass.sys_id, ass.status_code, ass.create_ts, ass.update_ts
	from
	(
		select * from acct_cte_condition
		UNION
		select * from acct_cte_no_condition where (select count(*) from acct_cte_condition) = 0
	) as acct
	join
	(
		select * from fac_cte_condition
		UNION
		select * from fac_cte_no_condition where (select count(*) from fac_cte_condition) = 0
	) as fac
		on acct.id = fac.acct_id
	join
	(
		select * from asset_cte_condition
		union
		select * from asset_cte_no_condition where (select count(*) from asset_cte_condition) = 0
	) as ass on fac.id = ass.fac_id
	join 
		user_facility uf on fac.id = uf.fac_id
	WHERE
		(uf.user_id = p_user_id OR p_user_id is null);

END;
' LANGUAGE plpgsql;
/
CALL drop_functions_by_name('upsert_asset_from_json');
/
CREATE OR REPLACE FUNCTION upsert_asset_from_json(
    p_jsonb_in jsonb, p_channel_name TEXT, p_user_id bigint
) 
RETURNS TABLE(id BIGINT, asset_nbr TEXT, sys_id TEXT, fac_nbr TEXT, fac_code TEXT) AS ' 
DECLARE
	unknown_fac_id bigint;
BEGIN
    SELECT f.id INTO unknown_fac_id
    FROM facility f
    WHERE upper(f.fac_nbr) = ''UNKNOWN'';

	CREATE TEMP TABLE temp_json_data AS
	SELECT 
	    --(p_jsonb ->> ''id'')::bigint AS id,
		p_jsonb ->> ''fac_nbr'' AS fac_nbr,	    
		p_jsonb ->> ''asset_nbr'' AS asset_nbr,
	    p_jsonb ->> ''sys_id'' AS sys_id
	FROM jsonb_array_elements(p_jsonb_in::JSONB) AS p_jsonb;

	DELETE from temp_json_data t where t.asset_nbr IS NULL;

	CREATE TEMP TABLE update_stage AS
	SELECT 
		coalesce(f.id) as fac_id,
		coalesce(t.fac_nbr, f.fac_nbr) as fac_nbr, 
		coalesce(t.asset_nbr, a.asset_nbr) as asset_nbr, 
		coalesce(t.sys_id, a.sys_id) as sys_id
	FROM	
	facility f 
	join asset a on f.Id = a.fac_id
	JOIN temp_json_data t on a.asset_nbr = t.asset_nbr;

	update update_stage t
	set fac_id = coalesce(f.id, unknown_fac_id)
	from facility f
	where t.fac_nbr = f.fac_nbr;
	
	-- remove upserts where the user does not have access to the facility
	IF p_user_id IS NOT NULL THEN
		DELETE from update_stage t
		WHERE 
			NOT EXISTS (select 1 FROM user_facility uf WHERE t.fac_id = uf.fac_id AND uf.user_id = p_user_id);
	END IF;

	-- Perform UPSERT: Insert new records or update existing ones
	MERGE INTO asset AS target
	USING update_stage AS source
	ON target.asset_nbr = source.asset_nbr
	WHEN MATCHED THEN
	    UPDATE SET 
	        sys_id = source.sys_id,
	        fac_id = source.fac_id,
	        update_ts = now()
	WHEN NOT MATCHED THEN
	    INSERT (asset_nbr, sys_id, fac_id, update_ts)
	    VALUES (source.asset_nbr, source.sys_id, source.fac_id, now());

    -- Raise event for consumers
    FOR asset_nbr IN
        SELECT a.asset_nbr 
		FROM asset a
		JOIN update_stage t ON a.asset_nbr = t.asset_nbr
    LOOP
		INSERT INTO event_notification_buffer(channel, payload, create_ts)
		VALUES (p_channel_name, asset_nbr, now());
        PERFORM pg_notify(p_channel_name, asset_nbr);
    END LOOP;
	
    -- Return the updated records
    RETURN QUERY 
    SELECT a.id, a.asset_nbr, a.sys_id, f.fac_nbr, f.fac_code
    FROM asset a
    JOIN facility f ON a.fac_id = f.id
	JOIN update_stage t ON a.asset_nbr = t.asset_nbr;
END;

' LANGUAGE plpgsql;
/
