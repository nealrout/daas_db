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
