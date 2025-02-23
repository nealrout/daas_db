CALL drop_functions_by_name('get_user_facility');
/
CREATE OR REPLACE FUNCTION get_user_facility(p_user_id BIGINT)
RETURNS TABLE(facility_code TEXT) AS '
BEGIN
    RETURN QUERY 
    SELECT f.facility_nbr
    FROM auth_user au 
    JOIN user_facility uf ON au.id = uf.user_id
    JOIN facility f ON uf.facility_id = f.id
    WHERE au.id = p_user_id;
END;
' LANGUAGE plpgsql;
/
CALL drop_functions_by_name('add_user_facility');
/
-- Stored procedure to get an asset by ID
CREATE OR REPLACE FUNCTION add_user_facility(p_jsonb jsonb, p_user_id bigint, p_delete_current_mappings bool default false)
RETURNS TABLE(username character varying, facility_nbr TEXT, create_ts timestamptz, update_ts timestamptz)
AS '
DECLARE
-- 	p_jsonb jsonb := ''{
--      "facility_nbr": ["INT_FAC_NBR_01", "INT_FAC_NBR_02"]
--  }'';
-- 	p_user_id bigint := 2;
BEGIN
	-- These drop statements are not required when deployed (they auto drop when out of scope).
	-- These are here to help when needing to test in a local session.
	drop table if exists parsed_keys;
	drop table if exists parsed_values;

	create temp table parsed_keys as
	select * from iterate_json_keys(p_jsonb);

	create temp table parsed_values as
	select 
		''facility_nbr'' as filter, get_jsonb_values_by_key (json_output, ''facility_nbr'') as value
		from parsed_keys;

	-- Pre delete all mappings, before adding new mappings.
	IF p_delete_current_mappings THEN
		delete from user_facility where user_id = p_user_id;
	END IF;
	

	insert into user_facility (user_id, facility_id, create_ts)
	select au.id, f.id, now()
	from 
		parsed_values v
	    JOIN facility f ON v.value = f.facility_nbr
	    JOIN auth_user au on p_user_id = au.id
		left join user_facility uf on f.id = uf.facility_id and au.id = uf.user_id
	where uf.facility_id is null;

    RETURN QUERY
    SELECT 
    au.username, f.facility_nbr, uf.create_ts, uf.update_ts
    FROM 
    user_facility uf 
    JOIN facility f ON uf.facility_id = f.id
    JOIN auth_user au on uf.user_id = au.id
    WHERE uf.user_id = p_user_id;  
END;
' LANGUAGE plpgsql;
/