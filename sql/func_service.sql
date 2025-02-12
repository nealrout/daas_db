CALL drop_functions_by_name('get_service');
/
-- Stored procedure to get all items
CREATE OR REPLACE FUNCTION get_service(p_user_id bigint)
RETURNS TABLE(id BIGINT, asset_nbr character varying, sys_id character varying, fac_code character varying, 
	service_nbr character varying, service_code character varying, service_name character varying, status_code character varying, create_ts timestamptz, update_ts timestamptz) AS '
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
RETURNS TABLE(id bigint, fac_code character varying, asset_nbr character varying, service_nbr character varying, service_code character varying,
service_name character varying, status_code character varying, create_ts timestamptz, update_ts timestamptz)
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
		select a.id, a.fac_id, a.asset_nbr
		from asset a
		JOIN get_jsonb_values_by_key (p_jsonb, ''asset_nbr'') k on a.asset_nbr = k.value
	),
	asset_cte_no_condition as (
		select a.id, a.fac_id, a.asset_nbr
		from asset a
	),
	service_cte_condition as (
		select s.id, s.asset_id, s.service_nbr, s.service_code, s.service_name, s.status_code, s.create_ts, s.update_ts
		from service s
		JOIN get_jsonb_values_by_key (p_jsonb, ''service_code'') k on s.service_code = k.value
		UNION ALL
		select s.id, s.asset_id, s.service_nbr, s.service_code, s.service_name, s.status_code, s.create_ts, s.update_ts
		from service s
		JOIN get_jsonb_values_by_key (p_jsonb, ''service_nbr'') k on s.service_nbr = k.value
	),
	service_cte_no_condition as (
		select s.id, s.asset_id, s.service_code, s.service_name, s.status_code, s.create_ts, s.update_ts
		from service s
	)
	
	select s.id, f.fac_code, a.asset_nbr, 
	s.service_nbr, s.service_code, s.service_name, s.status_code, s.create_ts, s.update_ts
	from
	(
		select id, fac_code from fac_cte_condition
		union all
		select id, fac_code from fac_cte_no_condition
		where (select count(*) from fac_cte_condition) = 0
	) f
	join
	(
		select id, fac_id, asset_nbr from asset_cte_condition
		union all
		select id, fac_id, asset_nbr from asset_cte_no_condition
		where (select count(*) from asset_cte_condition) = 0
	) a on f.id = a.fac_id
	join 
	(
		select id, asset_id, service_nbr, service_code, service_name, status_code, create_ts, update_ts from service_cte_condition
		union all
		select id, asset_id, service_nbr, service_code, service_name, status_code, create_ts, update_ts from service_cte_no_condition
		where (select count(*) from service_cte_condition) = 0
	) s on a.id = s.asset_id
	join
	user_facility uf on f.id = uf.fac_id;
END;
' LANGUAGE plpgsql;
/