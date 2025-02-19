CALL drop_functions_by_name('get_asset');
/
-- Stored procedure to get all items
CREATE OR REPLACE FUNCTION get_asset(p_user_id bigint DEFAULT NULL, p_source_ts timestamptz DEFAULT NULL, p_target_ts timestamptz DEFAULT NULL)
RETURNS TABLE(account_nbr text, facility_nbr TEXT, asset_nbr TEXT, sys_id TEXT, asset_code TEXT,status_code citext, create_ts timestamptz, update_ts timestamptz) 
AS '
BEGIN
    RETURN QUERY
    SELECT 
		acc.account_nbr, facility.facility_nbr, asset.asset_nbr, asset.sys_id, asset.asset_code, asset.status_code, asset.create_ts, asset.update_ts
	FROM 
		asset asset
    	JOIN facility facility on asset.facility_id = facility.id
		JOIN user_facility uf on facility.id = uf.facility_id
		JOIN account acc on facility.account_id = acc.id
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
RETURNS TABLE(account_nbr text, facility_nbr TEXT, asset_nbr TEXT, sys_id TEXT, asset_code TEXT, status_code citext, create_ts timestamptz, update_ts timestamptz)
AS '
DECLARE
--	p_jsonb jsonb := ''{
--    "account_nbr": ["ACCT_NBR_09"]
--    ,"facility_nbr": ["FAC_NBR_09", "FAC_NBR_20"]
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

	create temp table parsed_keys as
	select * from iterate_json_keys(p_jsonb);

	create temp table parsed_values as
	select 
		''account_nbr'' as filter, get_jsonb_values_by_key (json_output, ''account_nbr'') as value
		from parsed_keys
		union select 
		''facility_nbr'' as filter, get_jsonb_values_by_key (json_output, ''facility_nbr'') as value
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
--	create table res as select acct.account_nbr, fac.facility_nbr, a.asset_nbr, a.sys_id, a.status_code, a.create_ts, a.update_ts
--	from account acct join facility fac on acct.id = fac.account_id join asset a on fac.id = a.facility_id limit 0;
	
--	insert into res

	RETURN QUERY
	SELECT
	acc.account_nbr, fac.facility_nbr, a.asset_nbr, a.sys_id, a.asset_code, a.status_code, a.create_ts, a.update_ts
	FROM account acc
	JOIN facility fac ON acc.id = fac.account_id 
	JOIN asset a ON fac.id = a.facility_id 
	JOIN user_facility uf on fac.id = uf.facility_id
	WHERE 
		(
		EXISTS (SELECT 1 FROM parsed_values v WHERE v.FILTER = ''account_nbr'' AND acc.account_nbr = v.value)
		OR (SELECT count(*) FROM parsed_values v WHERE v.FILTER = ''account_nbr'') = 0
		)
		AND
		(
		EXISTS (SELECT 1 FROM parsed_values v WHERE v.FILTER = ''facility_nbr'' AND fac.facility_nbr = v.value)
		OR (SELECT count(*) FROM parsed_values v WHERE v.FILTER = ''facility_nbr'') = 0
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
    p_jsonb_in jsonb, p_channel_name TEXT, p_user_id bigint, p_parent_chennel_name TEXT default null
) 
RETURNS TABLE(account_nbr text, facility_nbr TEXT, asset_nbr TEXT, sys_id TEXT, asset_code TEXT, status_code citext, create_ts timestamptz, update_ts timestamptz) AS ' 
DECLARE
	unknown_facility_id bigint;
BEGIN
	-- Protect against malformed json based on what we are expecting.
    IF jsonb_typeof(p_jsonb_in) != ''array'' THEN
        RAISE WARNING ''Invalid JSONB input: Expected an array but got %'', jsonb_typeof(p_jsonb_in);
        RETURN;
    END IF;

    SELECT f.id INTO unknown_facility_id
    FROM facility f
    WHERE upper(f.facility_nbr) = ''UNKNOWN'';

	drop table if exists temp_json_data;
	drop table if exists update_stage;

	CREATE TEMP TABLE temp_json_data AS
	SELECT 
	    --(p_jsonb ->> ''id'')::bigint AS id,
		p_jsonb ->> ''facility_nbr'' AS facility_nbr,	    
		p_jsonb ->> ''asset_nbr'' AS asset_nbr,
		p_jsonb ->> ''asset_code'' AS asset_code,
	    p_jsonb ->> ''sys_id'' AS sys_id,
		p_jsonb ->> ''status_code'' AS status_code
	FROM jsonb_array_elements(p_jsonb_in::JSONB) AS p_jsonb;

	DELETE from temp_json_data t where t.asset_nbr IS NULL;

	CREATE TEMP TABLE update_stage AS
	SELECT 
		coalesce(f.id) as facility_id,
		coalesce(t.facility_nbr, f.facility_nbr) as facility_nbr, 
		coalesce(t.asset_nbr, a.asset_nbr) as asset_nbr, 
		coalesce(t.asset_code, a.asset_code) as asset_code, 
		coalesce(t.sys_id, a.sys_id) as sys_id,
		coalesce(astat.status_code, a.status_code, ''UNKNOWN'') as status_code
	FROM
	temp_json_data t
	left join asset a on t.asset_nbr = a.asset_nbr
	left join facility f on a.facility_id = f.id
	left join asset_status astat on t.status_code = astat.status_code;

	update update_stage t
	set facility_id = coalesce(f.id, unknown_facility_id)
	from facility f
	where t.facility_nbr = f.facility_nbr;
	
	-- remove upserts where the user does not have access to the facility
	IF p_user_id IS NOT NULL THEN
		DELETE from update_stage t
		WHERE 
			NOT EXISTS (select 1 FROM user_facility uf WHERE t.facility_id = uf.facility_id AND uf.user_id = p_user_id);
	END IF;

	-- Perform UPSERT: Insert new records or update existing ones
	MERGE INTO asset AS target
	USING update_stage AS source
	ON target.asset_nbr = source.asset_nbr
	WHEN MATCHED THEN
	    UPDATE SET 
	        sys_id = source.sys_id,
			asset_code = source.asset_code,
	        facility_id = source.facility_id,
			status_code = source.status_code,
	        update_ts = now()
	WHEN NOT MATCHED THEN
	    INSERT (asset_nbr, sys_id, asset_code, facility_id, status_code, create_ts)
	    VALUES (source.asset_nbr, source.sys_id, source.asset_code, source.facility_id, source.status_code, now());

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
    SELECT acc.account_nbr, f.facility_nbr, a.asset_nbr, a.sys_id, a.asset_code, a.status_code, a.create_ts, a.update_ts
    FROM asset a
    JOIN facility f ON a.facility_id = f.id
	JOIN account acc on f.account_id = acc.id
	JOIN update_stage t ON a.asset_nbr = t.asset_nbr;
END;

' LANGUAGE plpgsql;
/
