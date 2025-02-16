CALL drop_functions_by_name('get_service');
/
-- Stored procedure to get all items
CREATE OR REPLACE FUNCTION get_service(p_user_id bigint)
RETURNS TABLE(acct_nbr text, fac_nbr TEXT, asset_nbr TEXT, sys_id TEXT, svc_nbr TEXT, svc_code TEXT, svc_name TEXT, status_code CITEXT, create_ts timestamptz, update_ts timestamptz) 
AS '
BEGIN
    RETURN QUERY
    SELECT 
		account.acct_nbr, facility.fac_nbr, asset.asset_nbr, asset.sys_id, service.svc_nbr, service.svc_code, service.svc_name, service.status_code, service.create_ts, service.update_ts
	FROM 
		asset asset
		JOIN service service on asset.id = service.asset_id
		JOIN facility facility on asset.fac_id = facility.id
		JOIN account account on facility.acct_id = account.id
		JOIN user_facility uf on facility.id = uf.fac_id
	WHERE 
		(uf.user_id = p_user_id OR p_user_id is null);
END;
' LANGUAGE plpgsql;
/
CALL drop_functions_by_name('get_service_by_json');
/
-- Stored procedure to get an asset by ID
CREATE OR REPLACE FUNCTION get_service_by_json(p_jsonb jsonb, p_user_id bigint)
RETURNS TABLE(acct_nbr text, fac_nbr TEXT, asset_nbr TEXT, sys_id TEXT, svc_nbr TEXT, svc_code TEXT, svc_name TEXT, status_code CITEXT, create_ts timestamptz, update_ts timestamptz)
AS '
DECLARE
--	p_jsonb jsonb := ''{
--    "acct_nbr": ["ACCT_NBR_03"]
--    ,"fac_nbr": ["FAC_NBR_03"]
--    ,"asset_nbr": ["asset_29", "asset_30"]
--    ,"sys_id": ["system_09","system_10"]
--	,"svc_nbr": ["SVC_NBR_287","SVC_NBR_288"]
--	,"svc_code": ["SVC_007","SVC_008"]
--	,"svc_name": ["Service Name_007","Service Name_008"]
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
		''svc_nbr'' as filter, get_jsonb_values_by_key (json_output, ''svc_nbr'') as value
		from parsed_keys
		union select 
		''svc_code'' as filter, get_jsonb_values_by_key (json_output, ''svc_code'') as value
		from parsed_keys
		union select 
		''svc_name'' as filter, get_jsonb_values_by_key (json_output, ''svc_name'')::citext as value
		from parsed_keys
		union select 
		''status_code'' as filter, get_jsonb_values_by_key (json_output, ''status_code'')::citext as value
		from parsed_keys
		;

--	drop table if exists res;
--	create table res as select acct.acct_nbr, fac.fac_nbr, a.asset_nbr, a.sys_id, s.svc_nbr, s.svc_code, s.svc_name, s.status_code, s.create_ts, s.update_ts
--	from account acct join facility fac on acct.id = fac.acct_id join asset a on fac.id = a.fac_id join service s on a.id = s.asset_id limit 0;
--	
--	insert into res

	RETURN QUERY
	SELECT
		acc.acct_nbr, fac.fac_nbr, a.asset_nbr, a.sys_id, s.svc_nbr, s.svc_code, s.svc_name, s.status_code, s.create_ts, s.update_ts
	FROM account acc
	JOIN facility fac ON acc.id = fac.acct_id 
	JOIN asset a ON fac.id = a.fac_id 
	JOIN service s on a.id = s.asset_id
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
		EXISTS (SELECT 1 FROM parsed_values v WHERE v.FILTER = ''svc_nbr'' AND s.svc_nbr = v.value)
		OR (SELECT count(*) FROM parsed_values v WHERE v.FILTER = ''svc_nbr'') = 0
		)
		AND
		(
		EXISTS (SELECT 1 FROM parsed_values v WHERE v.FILTER = ''svc_code'' AND s.svc_code = v.value)
		OR (SELECT count(*) FROM parsed_values v WHERE v.FILTER = ''svc_code'') = 0
		)
		AND
		(
		EXISTS (SELECT 1 FROM parsed_values v WHERE v.FILTER = ''svc_name'' AND s.svc_name = v.value)
		OR (SELECT count(*) FROM parsed_values v WHERE v.FILTER = ''svc_name'') = 0
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
RETURNS TABLE(acct_nbr text, fac_nbr TEXT, asset_nbr TEXT, sys_id TEXT, svc_nbr TEXT, svc_code TEXT, svc_name TEXT, status_code CITEXT, create_ts timestamptz, update_ts timestamptz) AS ' 
DECLARE
BEGIN
	-- These drop statements are not required when deployed (they auto drop when out of scope).
	-- These are here to help when needing to test in a local session.
	drop table if exists temp_json_data;
	drop table if exists update_stage;

	CREATE TEMP TABLE temp_json_data AS
	SELECT 
		p_jsonb ->> ''asset_nbr'' AS asset_nbr,	    
		p_jsonb ->> ''svc_nbr'' AS svc_nbr,
	    p_jsonb ->> ''svc_code'' AS svc_code,
		p_jsonb ->> ''svc_name'' AS svc_name,
		p_jsonb ->> ''status_code'' AS status_code
	FROM jsonb_array_elements(p_jsonb_in::JSONB) AS p_jsonb;

	DELETE from temp_json_data t where t.svc_nbr IS NULL;

	CREATE TEMP TABLE update_stage AS
	SELECT 
		a.fac_id,
		coalesce(a_new.id, s.asset_id) as target_asset_id,
		coalesce(t.svc_nbr, s.svc_nbr) as svc_nbr, 
		coalesce(t.svc_code, s.svc_code) as svc_code, 
		coalesce(t.svc_name, s.svc_name) as svc_name, 
		coalesce(sstate.status_code, s.status_code, ''UNKNOWN'') as status_code
	FROM	
	temp_json_data t
	left join service s on t.svc_nbr = s.svc_nbr
	left join asset a on s.asset_id = a.id
	left join facility f on a.fac_id = f.id
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
			(select 1 FROM user_facility uf WHERE a.fac_id = uf.fac_id AND uf.user_id = p_user_id);
	END IF;

	-- Perform UPSERT: Insert new records or update existing ones
	MERGE INTO service AS target
	USING update_stage AS source
	ON target.svc_nbr = source.svc_nbr
	WHEN MATCHED THEN
	    UPDATE SET 
	        asset_id = source.target_asset_id,
	        svc_code = source.svc_code,
			svc_name = source.svc_name,
			status_code = source.status_code,
	        update_ts = now()
	WHEN NOT MATCHED THEN
	    INSERT (asset_id, svc_nbr, svc_code, svc_name, status_code, create_ts)
	    VALUES (source.target_asset_id, source.svc_nbr, source.svc_code, source.svc_name, source.status_code, now());

    -- Raise event for consumers
    FOR svc_nbr IN
        SELECT s.svc_nbr
		FROM service s
		JOIN update_stage t ON s.svc_nbr = t.svc_nbr
    LOOP
		INSERT INTO event_notification_buffer(channel, payload, create_ts)
		VALUES (p_channel_name, svc_nbr, now());
        PERFORM pg_notify(p_channel_name, asset_nbr);
    END LOOP;

    -- Return the updated records
    RETURN QUERY 
    SELECT acc.acct_nbr, f.fac_nbr, a.asset_nbr, a.sys_id, s.svc_nbr, s.svc_code, s.svc_name, s.status_code, s.create_ts, s.update_ts
    FROM service s
    JOIN asset a on s.asset_id = a.id
	JOIN facility f on a.fac_id = f.id
	JOIN account acc on f.acct_id = acc.id
	JOIN update_stage t ON s.svc_nbr = t.svc_nbr;
END;

' LANGUAGE plpgsql;
/
