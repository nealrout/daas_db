CALL drop_functions_by_name('get_facility');
/
-- Stored procedure to get all items
CREATE OR REPLACE FUNCTION get_facility(p_user_id bigint)
RETURNS TABLE(acct_nbr character varying, acct_code character varying, 
	fac_nbr character varying, fac_code character VARYING, fac_name character varying, create_ts timestamptz, update_ts timestamptz) AS '
BEGIN
    RETURN QUERY
    SELECT 
		ac.acct_nbr, ac.acct_code, f.fac_nbr, f.fac_code, f.fac_name, f.create_ts, f.update_ts
	FROM facility f
	JOIN user_facility uf on f.id = uf.fac_id
	JOIN account ac ON f.acct_id = ac.Id
	WHERE 
		(uf.user_id = p_user_id OR p_user_id is null);
END;
' LANGUAGE plpgsql;
/
CALL drop_functions_by_name('get_facility_by_id');
/
-- Stored procedure to get an asset by ID
CREATE OR REPLACE FUNCTION get_facility_by_id(p_jsonb jsonb, p_user_id bigint)
RETURNS TABLE(id bigint, fac_code character varying, asset_nbr character varying, sys_id character varying, create_ts timestamptz, update_ts timestamptz)
AS '
DECLARE
BEGIN
  	RETURN QUERY
	WITH fac_cte_condition as (
		select f.id, f.fac_code
		from facility f
		JOIN get_jsonb_values_by_key (p_jsonb, ''fac_code'') k on f.fac_code = k.value
	),
	fac_cte_no_condition as (
		select f.id, f.fac_code
		from facility f
	),
	asset_cte_condition as (
		select a.id, a.fac_id, a.asset_nbr, a.sys_id, a.create_ts, a.update_ts
		from asset a
		JOIN get_jsonb_values_by_key (p_jsonb, ''asset_nbr'') k on a.asset_nbr = k.value
	),
	asset_cte_no_condition as (
		select a.id, a.fac_id, a.asset_nbr, a.sys_id, a.create_ts, a.update_ts
		from asset a
	)

	select a.id, f.fac_code, a.asset_nbr, a.sys_id, a.create_ts, a.update_ts
	from
	(
		select fc.id, fc.fac_code from fac_cte_condition fc
		union all
		select fnc.id, fnc.fac_code from fac_cte_no_condition fnc
		where (select count(*) from fac_cte_condition) = 0
	) f
	join
	(
		select ac.id, ac.fac_id, ac.asset_nbr, ac.sys_id, ac.create_ts, ac.update_ts from asset_cte_condition ac
		union all
		select anc.id, anc.fac_id, anc.asset_nbr, anc.sys_id, anc.create_ts, anc.update_ts from asset_cte_no_condition anc
		where (select count(*) from asset_cte_condition) = 0
	) a on f.id = a.fac_id
	join
	user_facility uf on f.id = uf.fac_id
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
RETURNS TABLE(id BIGINT, asset_nbr character varying, sys_id character varying, fac_nbr character varying, fac_code character varying) AS ' 
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
