CALL drop_functions_by_name('get_userfacility_by_user');
/
CREATE OR REPLACE FUNCTION get_userfacility_by_user(p_user_id BIGINT)
RETURNS TABLE(facility_code TEXT) AS '
BEGIN
    RETURN QUERY 
    SELECT f.facility_nbr
    FROM auth_user au 
    JOIN userfacility uf ON au.id = uf.user_id
    JOIN facility f ON uf.facility_id = f.id
    WHERE au.id = p_user_id;
END;
' LANGUAGE plpgsql;
/
CALL drop_functions_by_name('get_userfacility');
/
CREATE OR REPLACE FUNCTION get_userfacility(p_user_id bigint DEFAULT NULL, p_source_ts timestamptz DEFAULT NULL, p_target_ts timestamptz DEFAULT NULL)
RETURNS TABLE(username character varying, facility_nbr jsonb) AS '
BEGIN
    RETURN QUERY 
    SELECT au.username, jsonb_agg(f.facility_nbr) as facility_nbr
    FROM auth_user au 
    LEFT JOIN userfacility uf ON au.id = uf.user_id
    LEFT JOIN facility f ON uf.facility_id = f.id
	WHERE -- Person selecting this is a super user, or p_user_id was not specified
		(
			(SELECT count(*) FROM auth_user auin WHERE auin.is_superuser = TRUE AND auin.id = p_user_id) >0 
			OR p_user_id IS NULL
		)
		OR au.id = p_user_id		
	GROUP BY au.username;
END;
' LANGUAGE plpgsql;
/
CALL drop_functions_by_name('get_userfacility_by_json');
/
-- Stored procedure to get an asset by ID

CREATE OR REPLACE FUNCTION get_userfacility_by_json(p_jsonb jsonb, p_user_id bigint default NULL)
RETURNS TABLE(username character varying, facility_nbr jsonb)
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
		from parsed_keys;

	RETURN QUERY
	
	SELECT au.username, jsonb_agg(f.facility_nbr) as facility_nbr
    FROM auth_user au 
    LEFT JOIN userfacility uf ON au.id = uf.user_id
    LEFT JOIN facility f ON uf.facility_id = f.id
	WHERE 
		(-- Person selecting this is a super user, or p_user_id was not specified
			(
				(SELECT count(*) FROM auth_user auin WHERE auin.is_superuser = TRUE AND auin.id = p_user_id) >0 
				OR p_user_id IS NULL
			)
			OR au.id = p_user_id		
		)
		AND
		(
		EXISTS (SELECT 1 FROM parsed_values v WHERE v.filter = ''username'' AND au.username = v.value)
		OR (SELECT count(*) FROM parsed_values v WHERE v.filter = ''username'') = 0
        )
	GROUP BY au.username;

END;
' LANGUAGE plpgsql;
/
CALL drop_functions_by_name('upsert_userfacility_from_json');
/
CREATE OR REPLACE FUNCTION upsert_userfacility_from_json(
    p_jsonb_in jsonb, p_channel_name TEXT, p_user_id bigint, p_parent_chennel_name TEXT default null, p_delete_current_mappings bool default false
) 
RETURNS TABLE(username character varying, facility_nbr jsonb) AS ' 
DECLARE
BEGIN
	IF (SELECT count(*) FROM auth_user auin WHERE auin.is_superuser = TRUE AND auin.id = p_user_id) = 0 THEN
		RAISE WARNING ''user_id %s does not have super_user permission'', p_user_id;
		RETURN;
	END IF;

	-- These drop statements are not required when deployed (they auto drop when out of scope).
	-- These are here to help when needing to test in a local session.
	drop table if exists temp_json_data;
	drop table if exists update_stage;

	-- New table to handle an array of facility_nbr per user.
    CREATE TEMP TABLE temp_json_data AS
    SELECT 
        p_jsonb_in ->> ''username'' AS username,  
        jsonb_array_elements_text(p_jsonb_in -> ''facility_nbr'') AS facility_nbr
    ;

	-- OLD TABLE FOR HANDLING a json record for each user.
	-- CREATE TEMP TABLE temp_json_data AS
	-- SELECT 
	-- 	p_jsonb ->> ''username'' AS username,	    
	-- 	p_jsonb ->> ''facility_nbr'' AS facility_nbr
	-- FROM jsonb_array_elements(p_jsonb_in::JSONB) AS p_jsonb;

	DELETE from temp_json_data t where t.username IS NULL;

	CREATE TEMP TABLE update_stage AS
	SELECT 
		au.id as user_id,
		coalesce(t.username, au.username) as username, 
		f.id as facility_id
	FROM	
	temp_json_data t
	join auth_user au on t.username = au.username
	join facility f on t.facility_nbr = f.facility_nbr;

	-- Pre delete all mappings, before adding new mappings.
	IF p_delete_current_mappings THEN
		delete from userfacility 
		USING update_stage t
		where userfacility.user_id = t.user_id;
	END IF;

	insert into userfacility (user_id, facility_id, create_ts)
	select t.user_id, t.facility_id, now()
	from update_stage t
		where not exists (select 1 from userfacility ufin where t.user_id = ufin.user_id and t.facility_id =  ufin.facility_id);

    -- Raise event for consumers
    FOR username IN
        SELECT au.username
		FROM auth_user au
		JOIN update_stage t ON au.id = t.user_id
    LOOP
		INSERT INTO event_notification_buffer(channel, payload, create_ts)
		VALUES (p_channel_name, username, now());
        PERFORM pg_notify(p_channel_name, username);
    END LOOP;
	
    -- Return the updated records
    RETURN QUERY 
	SELECT q.username, jsonb_agg(q.facility_nbr) as facility_nbr
	FROM
	(
		SELECT DISTINCT au.username , f.facility_nbr
		FROM auth_user au 
		JOIN userfacility uf ON au.id = uf.user_id
		JOIN facility f ON uf.facility_id = f.id
		JOIN update_stage t ON au.id = t.user_id
	) q 
	GROUP BY q.username;
END;

' LANGUAGE plpgsql;
/
CALL drop_functions_by_name('add_userfacility');
/
-- Stored procedure to get an asset by ID
CREATE OR REPLACE FUNCTION add_userfacility(p_jsonb jsonb, p_user_id bigint, p_delete_current_mappings bool default false)
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
		delete from userfacility where user_id = p_user_id;
	END IF;
	
	insert into userfacility (user_id, facility_id, create_ts)
	select au.id, f.id, now()
	from 
		parsed_values v
	    JOIN facility f ON v.value = f.facility_nbr
	    JOIN auth_user au on p_user_id = au.id
		left join userfacility uf on f.id = uf.facility_id and au.id = uf.user_id
	where uf.facility_id is null;

    RETURN QUERY
    SELECT 
    au.username, f.facility_nbr, uf.create_ts, uf.update_ts
    FROM 
    userfacility uf 
    JOIN facility f ON uf.facility_id = f.id
    JOIN auth_user au on uf.user_id = au.id
    WHERE uf.user_id = p_user_id;  
END;
' LANGUAGE plpgsql;
/