CALL drop_functions_by_name('get_service');
/
-- Stored procedure to get all items
CREATE OR REPLACE FUNCTION get_service(p_user_id bigint)
RETURNS TABLE(id BIGINT, asset_nbr TEXT, sys_id TEXT, fac_code TEXT, 
	service_nbr TEXT, service_code TEXT, service_name TEXT, status_code CITEXT, create_ts timestamptz, update_ts timestamptz) 
AS '
BEGIN
    RETURN QUERY
    SELECT 
		asset.id, asset.asset_nbr, asset.sys_id, 
		facility.fac_code, 
		service.service_nbr, service.service_code, service.service_name, service.status_code, service.create_ts, service.update_ts
	FROM 
		asset asset
		JOIN service service on asset.id = service.asset_id
		JOIN facility facility on asset.fac_id = facility.id
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
RETURNS TABLE(acct_nbr TEXT, fac_nbr TEXT, asset_nbr TEXT, sys_id TEXT, service_nbr TEXT, service_code TEXT, svc_name TEXT, status_code CITEXT, create_ts timestamptz, update_ts timestamptz)
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