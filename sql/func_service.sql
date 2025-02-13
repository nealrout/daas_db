CALL drop_functions_by_name('get_service');
/
-- Stored procedure to get all items
CREATE OR REPLACE FUNCTION get_service(p_user_id bigint)
RETURNS TABLE(id BIGINT, asset_nbr TEXT, sys_id TEXT, fac_code TEXT, 
	service_nbr TEXT, service_code TEXT, service_name TEXT, status_code TEXT, create_ts timestamptz, update_ts timestamptz) 
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
CALL drop_functions_by_name('get_service_by_id');
/
-- Stored procedure to get an asset by ID
CREATE OR REPLACE FUNCTION get_service_by_id(p_jsonb jsonb, p_user_id bigint)
RETURNS TABLE(acct_nbr TEXT, fac_nbr TEXT, asset_nbr TEXT, sys_id TEXT, service_nbr TEXT, service_code TEXT, svc_name TEXT, status_code TEXT, create_ts timestamptz, update_ts timestamptz)
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
		get_jsonb_values_by_key (json_output, ''svc_nbr'') as svc_nbr,
		get_jsonb_values_by_key (json_output, ''svc_code'') as svc_code,
		get_jsonb_values_by_key (json_output, ''svc_name'') as svc_name,
		get_jsonb_values_by_key (json_output, ''status_code'') as status_code
	from parsed_keys p;

--	create table res as select acct.acct_nbr, acct.acct_code, fac.fac_nbr, fac.fac_code, fac.fac_name, fac.create_ts, fac.update_ts 
--	from account acct join facility fac on acct.id = fac.acct_id limit 0;

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
	),
	asset_cte_no_condition as (
		select a.*
		from asset a
	),
	service_cte_condition as (
		select s.*
		from service s
		join parsed_values v on s.svc_nbr = v.svc_nbr
		union 
		select s.*
		from service s
		join parsed_values v on s.svc_code = v.svc_code
		union 
		select s.*
		from service s
		join parsed_values v on s.svc_name = v.svc_name
		union 
		select s.*
		from service s
		join parsed_values v on s.status_code = v.status_code
	
	),
	service_cte_no_condition as (
		select s.*
		from service s	
	)

--	insert into res
	
	select acct.acct_nbr, fac.fac_nbr, ass.asset_nbr, ass.sys_id, ser.svc_nbr, ser.svc_code, ser.svc_name, ser.status_code, ser.create_ts, ser.update_ts
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
	(
		select * from service_cte_condition
		union
		select * from service_cte_no_condition where (select count(*) from service_cte_condition) = 0
	) as ser on ass.id = ser.asset_id
	join 
		user_facility uf on fac.id = uf.fac_id
	WHERE
		(uf.user_id = p_user_id OR p_user_id is null);

END;
' LANGUAGE plpgsql;
/