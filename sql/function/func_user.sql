CALL drop_functions_by_name('get_user');
/
-- Stored procedure to get all items
CREATE OR REPLACE FUNCTION get_user(p_user_id bigint DEFAULT NULL, p_source_ts timestamptz DEFAULT NULL, p_target_ts timestamptz DEFAULT NULL)
RETURNS TABLE(username character varying, first_name character varying, last_name character varying, email character varying, is_staff bool, is_superuser bool, is_active bool, last_login timestamptz, fac_nbr jsonb)
AS '
BEGIN
    RETURN QUERY

    SELECT au.username, au.first_name, au.last_name, au.email, au.is_staff, au.is_superuser, au.is_active, au.last_login
    ,jsonb_agg(f.facility_nbr) as facility_nbr
    FROM auth_user au 
    LEFT JOIN user_facility uf ON au.id = uf.user_id
    LEFT JOIN facility f ON uf.facility_id  = f.Id
    WHERE
    	(au.id = p_user_id OR p_user_id is null)
    GROUP BY au.username, au.first_name, au.last_name, au.email, au.is_staff, au.is_superuser, au.is_active, au.last_login;
END;
' LANGUAGE plpgsql;
/
CALL drop_functions_by_name('get_user_by_json');
/
-- Stored procedure to get an asset by ID

CREATE OR REPLACE FUNCTION get_user_by_json(p_jsonb jsonb, p_user_id bigint default NULL)
RETURNS TABLE(username character varying, first_name character varying, last_name character varying, email character varying, is_staff bool, is_superuser bool, is_active bool, last_login timestamptz, fac_nbr jsonb)
AS '
DECLARE
--	p_jsonb jsonb := ''{
--		"username": ["daas","asdf"]
--    }'';
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
		''username'' as filter, get_jsonb_values_by_key (json_output, ''username'') as value
		from parsed_keys
		union select 
		''first_name'' as filter, get_jsonb_values_by_key (json_output, ''first_name'') as value
		from parsed_keys
		union select 
		''last_name'' as filter, get_jsonb_values_by_key (json_output, ''last_name'')::CITEXT as value
		from parsed_keys
        union select 
		''email'' as filter, get_jsonb_values_by_key (json_output, ''email'')::CITEXT as value
		from parsed_keys;


	RETURN QUERY
    SELECT 
        au.username, au.first_name, au.last_name, au.email, au.is_staff, au.is_superuser, au.is_active, au.last_login
        ,jsonb_agg(f.facility_nbr) as facility_nbr
    FROM auth_user au 
    LEFT JOIN user_facility uf ON au.id = uf.user_id
    LEFT JOIN facility f ON uf.facility_id  = f.Id
	WHERE 
		(
		EXISTS (SELECT 1 FROM parsed_values v WHERE v.filter = ''username'' AND au.username = v.value)
		OR (SELECT count(*) FROM parsed_values v WHERE v.filter = ''username'') = 0
        )
		AND
		(
		EXISTS (SELECT 1 FROM parsed_values v WHERE v.FILTER = ''first_name'' AND au.first_name = v.value)
		OR (SELECT count(*) FROM parsed_values v WHERE v.FILTER = ''first_name'') = 0
		)
		AND
		(
		EXISTS (SELECT 1 FROM parsed_values v WHERE v.FILTER = ''last_name'' AND au.last_name = v.value)
		OR (SELECT count(*) FROM parsed_values v WHERE v.FILTER = ''last_name'') = 0
		)
		AND
		(
		EXISTS (SELECT 1 FROM parsed_values v WHERE v.FILTER = ''email'' AND au.email = v.value)
		OR (SELECT count(*) FROM parsed_values v WHERE v.FILTER = ''email'') = 0
		)
		AND (au.id = p_user_id OR p_user_id is null)
	GROUP BY
		au.username, au.first_name, au.last_name, au.email, au.is_staff, au.is_superuser, au.is_active, au.last_login;

END;
' LANGUAGE plpgsql;
/
CALL drop_functions_by_name('upsert_user_from_json');
/
CREATE OR REPLACE FUNCTION upsert_user_from_json(
    p_jsonb_in jsonb, p_channel_name TEXT, p_user_id bigint, p_parent_chennel_name TEXT default null
) 
RETURNS TABLE(username character varying, first_name character varying, last_name character varying, email character varying, is_staff bool, is_superuser bool, is_active bool, last_login timestamptz, fac_nbr jsonb) AS ' 
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
		p_jsonb ->> ''username'' AS username,	    
		p_jsonb ->> ''first_name'' AS first_name,
		p_jsonb ->> ''last_name'' AS last_name,
        p_jsonb ->> ''email'' AS email
	FROM jsonb_array_elements(p_jsonb_in::JSONB) AS p_jsonb;

	DELETE from temp_json_data t where t.username IS NULL;

	CREATE TEMP TABLE update_stage AS
	SELECT 
		au.id as id,
		coalesce(t.username, au.username) as username, 
		coalesce(t.first_name, au.first_name) as first_name, 
		coalesce(t.last_name, au.last_name) as last_name,
        coalesce(t.email, au.email) as email
	FROM	
	temp_json_data t
	left join auth_user au on t.username = au.username;

	-- Perform UPSERT: Insert new records or update existing ones
	MERGE INTO auth_user AS target
	USING update_stage AS source
	ON target.id = source.id
	WHEN MATCHED THEN
	    UPDATE SET 
	        username = source.username,
			first_name = source.first_name,
            last_name = source.last_name,
            email = source.email;

    -- Raise event for consumers
    FOR username IN
        SELECT au.username
		FROM auth_user au
		JOIN update_stage t ON au.username = t.username
    LOOP
		INSERT INTO event_notification_buffer(channel, payload, create_ts)
		VALUES (p_channel_name, username, now());
        PERFORM pg_notify(p_channel_name, username);
    END LOOP;
	
    -- Return the updated records
    RETURN QUERY 
    SELECT  au.username, au.first_name, au.last_name, au.email, au.is_staff, au.is_superuser, au.is_active, au.last_login
        ,jsonb_agg(f.facility_nbr) as facility_nbr
    FROM auth_user au 
    LEFT JOIN user_facility uf ON au.id = uf.user_id
    LEFT JOIN facility f ON uf.facility_id  = f.Id
	JOIN update_stage t ON au.id = t.id
	GROUP BY
		au.username, au.first_name, au.last_name, au.email, au.is_staff, au.is_superuser, au.is_active, au.last_login;
END;

' LANGUAGE plpgsql;
/
