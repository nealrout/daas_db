CALL drop_functions_by_name('get_service');
/
-- Stored procedure to get all items
CREATE OR REPLACE FUNCTION get_service(p_user_id bigint DEFAULT NULL, p_source_ts timestamptz DEFAULT NULL, p_target_ts timestamptz DEFAULT NULL)
RETURNS TABLE(account_nbr text, facility_nbr TEXT, asset_nbr TEXT, sys_id TEXT, service_nbr TEXT, service_code TEXT, service_name TEXT, status_code CITEXT, create_ts timestamptz, update_ts timestamptz) 
AS '
BEGIN
    RETURN QUERY
    SELECT 
		account.account_nbr, facility.facility_nbr, asset.asset_nbr, asset.sys_id, service.service_nbr, service.service_code, service.service_name, service.status_code, service.create_ts, service.update_ts
	FROM 
		asset asset
		JOIN service service on asset.id = service.asset_id
		JOIN facility facility on asset.facility_id = facility.id
		JOIN account account on facility.account_id = account.id
		JOIN user_facility uf on facility.id = uf.facility_id
	WHERE 
		(
			(p_source_ts IS NOT NULL AND service.update_ts >= p_source_ts)
			OR 
			p_source_ts IS NULL
		)
		AND
		(
			(p_target_ts IS NOT NULL AND service.update_ts <= p_target_ts)
			OR
			p_target_ts IS NULL
		)
		AND
			(uf.user_id = p_user_id OR p_user_id is null);
END;
' LANGUAGE plpgsql;
/
CALL drop_functions_by_name('get_service_by_json');
/
-- Stored procedure to get an asset by ID
CREATE OR REPLACE FUNCTION get_service_by_json(p_jsonb jsonb, p_user_id bigint)
RETURNS TABLE(account_nbr text, facility_nbr TEXT, asset_nbr TEXT, sys_id TEXT, service_nbr TEXT, service_code TEXT, service_name TEXT, status_code CITEXT, create_ts timestamptz, update_ts timestamptz)
AS '
DECLARE
--	p_jsonb jsonb := ''{
--    "account_nbr": ["ACCT_NBR_03"]
--    ,"facility_nbr": ["FAC_NBR_03"]
--    ,"asset_nbr": ["asset_29", "asset_30"]
--    ,"sys_id": ["system_09","system_10"]
--	,"service_nbr": ["SVC_NBR_287","SVC_NBR_288"]
--	,"service_code": ["SVC_007","SVC_008"]
--	,"service_name": ["Service Name_007","Service Name_008"]
--    ,"status_code": ["UNKNOWN"]
--}'';
--
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
		''service_nbr'' as filter, get_jsonb_values_by_key (json_output, ''service_nbr'') as value
		from parsed_keys
		union select 
		''service_code'' as filter, get_jsonb_values_by_key (json_output, ''service_code'') as value
		from parsed_keys
		union select 
		''service_name'' as filter, get_jsonb_values_by_key (json_output, ''service_name'')::citext as value
		from parsed_keys
		union select 
		''status_code'' as filter, get_jsonb_values_by_key (json_output, ''status_code'')::citext as value
		from parsed_keys
		;

--	drop table if exists res;
--	create table res as select acct.account_nbr, fac.facility_nbr, a.asset_nbr, a.sys_id, s.service_nbr, s.service_code, s.service_name, s.status_code, s.create_ts, s.update_ts
--	from account acct join facility fac on acct.id = fac.account_id join asset a on fac.id = a.facility_id join service s on a.id = s.asset_id limit 0;
--	
--	insert into res

	RETURN QUERY
	SELECT
		acc.account_nbr, fac.facility_nbr, a.asset_nbr, a.sys_id, s.service_nbr, s.service_code, s.service_name, s.status_code, s.create_ts, s.update_ts
	FROM account acc
	JOIN facility fac ON acc.id = fac.account_id 
	JOIN asset a ON fac.id = a.facility_id 
	JOIN service s on a.id = s.asset_id
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
		EXISTS (SELECT 1 FROM parsed_values v WHERE v.FILTER = ''service_nbr'' AND s.service_nbr = v.value)
		OR (SELECT count(*) FROM parsed_values v WHERE v.FILTER = ''service_nbr'') = 0
		)
		AND
		(
		EXISTS (SELECT 1 FROM parsed_values v WHERE v.FILTER = ''service_code'' AND s.service_code = v.value)
		OR (SELECT count(*) FROM parsed_values v WHERE v.FILTER = ''service_code'') = 0
		)
		AND
		(
		EXISTS (SELECT 1 FROM parsed_values v WHERE v.FILTER = ''service_name'' AND s.service_name = v.value)
		OR (SELECT count(*) FROM parsed_values v WHERE v.FILTER = ''service_name'') = 0
		)
		AND
		(
		EXISTS (SELECT 1 FROM parsed_values v WHERE v.FILTER = ''status_code'' AND s.status_code = v.value)
		OR (SELECT count(*) FROM parsed_values v WHERE v.FILTER = ''status_code'') = 0
		)
		AND	(uf.user_id = p_user_id OR p_user_id is null);
		
END;
' LANGUAGE plpgsql;
/
CALL drop_functions_by_name('upsert_service_from_json');
/
CREATE OR REPLACE FUNCTION upsert_service_from_json(
    p_jsonb_in jsonb, p_channel_name TEXT, p_user_id bigint default null
) 
RETURNS TABLE(account_nbr text, facility_nbr TEXT, asset_nbr TEXT, sys_id TEXT, service_nbr TEXT, service_code TEXT, service_name TEXT, status_code CITEXT, create_ts timestamptz, update_ts timestamptz) AS ' 
DECLARE
BEGIN
	-- Protect against malformed json based on what we are expecting.
    IF jsonb_typeof(p_jsonb_in) != ''array'' THEN
        RAISE WARNING ''Invalid JSONB input: Expected an array but got %'', jsonb_typeof(p_jsonb_in);
        RETURN;
    END IF;
	
	-- These drop statements are not required when deployed (they auto drop when out of scope).
	-- These are here to help when needing to test in a local session.
	drop table if exists temp_json_data;
	drop table if exists update_stage;

	CREATE TEMP TABLE temp_json_data AS
	SELECT 
		p_jsonb ->> ''asset_nbr'' AS asset_nbr,	    
		p_jsonb ->> ''service_nbr'' AS service_nbr,
	    p_jsonb ->> ''service_code'' AS service_code,
		p_jsonb ->> ''service_name'' AS service_name,
		p_jsonb ->> ''status_code'' AS status_code
	FROM jsonb_array_elements(p_jsonb_in::JSONB) AS p_jsonb;

	DELETE from temp_json_data t where t.service_nbr IS NULL;

	CREATE TEMP TABLE update_stage AS
	SELECT 
		a.facility_id,
		coalesce(a_new.id, s.asset_id) as target_asset_id,
		coalesce(t.service_nbr, s.service_nbr) as service_nbr, 
		coalesce(t.service_code, s.service_code) as service_code, 
		coalesce(t.service_name, s.service_name) as service_name, 
		coalesce(sstate.status_code, s.status_code, ''UNKNOWN'') as status_code
	FROM	
	temp_json_data t
	left join service s on t.service_nbr = s.service_nbr
	left join asset a on s.asset_id = a.id
	left join facility f on a.facility_id = f.id
	left join asset a_new on t.asset_nbr = a_new.asset_nbr
	left join service_status sstate on t.status_code = sstate.status_code;
	
	-- asset is a requirement to insert or update an sr.
	DELETE from update_stage where target_asset_id IS NULL;

	-- remove upserts where the user does not have access to the facility
	IF p_user_id IS NOT NULL THEN
		DELETE FROM update_stage t
		USING asset a 
		WHERE t.target_asset_id = a.id
		AND NOT EXISTS 
			(select 1 FROM user_facility uf WHERE a.facility_id = uf.facility_id AND uf.user_id = p_user_id);
	END IF;

	-- Perform UPSERT: Insert new records or update existing ones
	MERGE INTO service AS target
	USING update_stage AS source
	ON target.service_nbr = source.service_nbr
	WHEN MATCHED THEN
	    UPDATE SET 
	        asset_id = source.target_asset_id,
	        service_code = source.service_code,
			service_name = source.service_name,
			status_code = source.status_code,
	        update_ts = now()
	WHEN NOT MATCHED THEN
	    INSERT (asset_id, service_nbr, service_code, service_name, status_code, create_ts)
	    VALUES (source.target_asset_id, source.service_nbr, source.service_code, source.service_name, source.status_code, now());

    -- Raise event for consumers
    FOR service_nbr IN
        SELECT s.service_nbr
		FROM service s
		JOIN update_stage t ON s.service_nbr = t.service_nbr
    LOOP
		INSERT INTO event_notification_buffer(channel, payload, create_ts)
		VALUES (p_channel_name, service_nbr, now());
        PERFORM pg_notify(p_channel_name, service_nbr);
    END LOOP;

    -- Return the updated records
    RETURN QUERY 
    SELECT acc.account_nbr, f.facility_nbr, a.asset_nbr, a.sys_id, s.service_nbr, s.service_code, s.service_name, s.status_code, s.create_ts, s.update_ts
    FROM service s
    JOIN asset a on s.asset_id = a.id
	JOIN facility f on a.facility_id = f.id
	JOIN account acc on f.account_id = acc.id
	JOIN update_stage t ON s.service_nbr = t.service_nbr;
END;

' LANGUAGE plpgsql;
/
