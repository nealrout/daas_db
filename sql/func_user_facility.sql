CALL drop_functions_by_name('get_user_facility');
/
CREATE OR REPLACE FUNCTION get_user_facility(p_user_id BIGINT)
RETURNS TABLE(fac_code TEXT) AS '
BEGIN
    RETURN QUERY 
    SELECT f.fac_code
    FROM auth_user au 
    JOIN user_facility uf ON au.id = uf.user_id
    JOIN facility f ON uf.fac_id = f.id
    WHERE au.id = p_user_id;
END;
' LANGUAGE plpgsql;
