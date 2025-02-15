CALL drop_functions_by_name('get_asset');
/
-- Stored procedure to get all items
CREATE OR REPLACE FUNCTION get_asset(p_user_id bigint DEFAULT NULL, p_source_ts timestamptz DEFAULT NULL, p_target_ts timestamptz DEFAULT NULL)
RETURNS TABLE(id BIGINT, fac_nbr TEXT, fac_code TEXT, asset_nbr TEXT, sys_id TEXT, create_ts timestamptz, update_ts timestamptz) 
AS '
BEGIN
    RETURN QUERY
    SELECT 
		asset.id, facility.fac_nbr, facility.fac_code , asset.asset_nbr, asset.sys_id, asset.create_ts, asset.update_ts
	FROM 
		asset asset
    	JOIN facility facility on asset.fac_id = facility.id
		JOIN user_facility uf on facility.id = uf.fac_id
	WHERE 
		(
			(p_source_ts IS NOT NULL AND asset.update_ts >= p_source_ts)
			OR 
			p_source_ts IS NULL
		)
		AND
		(
			(p_target_ts IS NOT NULL AND asset.update_ts <= p_target_ts)
			OR
			p_target_ts IS NULL
		)
		AND
			(uf.user_id = p_user_id OR p_user_id is null);
END;
' LANGUAGE plpgsql;
/
CALL drop_functions_by_name('get_asset_by_json');
/
-- Stored procedure to get an asset by ID
CREATE OR REPLACE FUNCTION get_asset_by_json(p_jsonb jsonb, p_user_id bigint default NULL)
RETURNS TABLE(acct_nbr text, fac_nbr text, asset_nbr text, sys_id text, status_code CITEXT, create_ts timestamptz, update_ts timestamptz)
AS '
DECLARE
--	p_jsonb jsonb := ''{
--    "acct_nbr": ["ACCT_NBR_09"]
--    ,"fac_nbr": ["FAC_NBR_09", "FAC_NBR_20"]
--    ,"asset_nbr": ["asset_82", "asset_83"]
--    ,"sys_id": ["system_03","system_02"]
--    ,"status_code": ["up"]
--}'';
--	p_user_id bigint := 2;
BEGIN
	-- These drop statements are not required when deployed (they auto drop when out of scope).
	-- These are here to help when needing to test in a local session.
	drop table if exists parsed_keys;
	drop table if exists parsed_values;

	create table parsed_keys as
	select * from iterate_json_keys(p_jsonb);

	create temp table parsed_values as
	select 
		''acct_nbr'' as filter, get_jsonb_values_by_key (json_output, ''acct_nbr'') as value
		from parsed_keys
		union select 
		''fac_nbr'' as filter, get_jsonb_values_by_key (json_output, ''fac_nbr'') as value
		from parsed_keys
		union select 
		''asset_nbr'' as filter, get_jsonb_values_by_key (json_output, ''asset_nbr'') as value
		from parsed_keys
		union select 
		''sys_id'' as filter, get_jsonb_values_by_key (json_output, ''sys_id'') as value
		from parsed_keys
		union select 
		''status_code'' as filter, get_jsonb_values_by_key (json_output, ''status_code'')::citext as value
		from parsed_keys;

--	drop table if exists res;
--	create table res as select acct.acct_nbr, fac.fac_nbr, a.asset_nbr, a.sys_id, a.status_code, a.create_ts, a.update_ts
--	from account acct join facility fac on acct.id = fac.acct_id join asset a on fac.id = a.fac_id limit 0;
	
--	insert into res

	RETURN QUERY
	SELECT
	acc.acct_nbr, fac.fac_nbr, a.asset_nbr, a.sys_id, a.status_code, a.create_ts, a.update_ts
	FROM account acc
	JOIN facility fac ON acc.id = fac.acct_id 
	JOIN asset a ON fac.id = a.fac_id 
	JOIN user_facility uf on fac.id = uf.fac_id
	WHERE 
		(
		EXISTS (SELECT 1 FROM parsed_values v WHERE v.FILTER = ''acct_nbr'' AND acc.acct_nbr = v.value)
		OR (SELECT count(*) FROM parsed_values v WHERE v.FILTER = ''acct_nbr'') = 0
		)
		AND
		(
		EXISTS (SELECT 1 FROM parsed_values v WHERE v.FILTER = ''fac_nbr'' AND fac.fac_nbr = v.value)
		OR (SELECT count(*) FROM parsed_values v WHERE v.FILTER = ''fac_nbr'') = 0
		)
		AND
		(
		EXISTS (SELECT 1 FROM parsed_values v WHERE v.FILTER = ''asset_nbr'' AND a.asset_nbr = v.value)
		OR (SELECT count(*) FROM parsed_values v WHERE v.FILTER = ''asset_nbr'') = 0
		)
		AND
		(
		EXISTS (SELECT 1 FROM parsed_values v WHERE v.FILTER = ''sys_id'' AND a.sys_id = v.value)
		OR (SELECT count(*) FROM parsed_values v WHERE v.FILTER = ''sys_id'') = 0
		)
		AND
		(
		EXISTS (SELECT 1 FROM parsed_values v WHERE v.FILTER = ''status_code'' AND a.status_code = v.value)
		OR (SELECT count(*) FROM parsed_values v WHERE v.FILTER = ''status_code'') = 0
		)
		AND	(uf.user_id = p_user_id OR p_user_id is null);
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

	drop table if exists temp_json_data;
	drop table if exists update_stage;

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
