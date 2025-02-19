CALL drop_functions_by_name('get_auth_user');
/
CREATE OR REPLACE FUNCTION get_auth_user(p_username character varying)
RETURNS TABLE(id int, username character varying, email character varying, first_name character varying, last_name character varying, is_active bool, last_login timestamptz) AS '
BEGIN
    RETURN QUERY 
    SELECT au.id, au.username, au.email, au.first_name, au.last_name, au.is_active, au.last_login 
	FROM auth_user au
	where au.username = p_username;
END;
' LANGUAGE plpgsql;
/
