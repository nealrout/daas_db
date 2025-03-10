CALL drop_functions_by_name('get_account');
/
-- Stored procedure to get all items
CREATE OR REPLACE FUNCTION get_account(p_user_id bigint DEFAULT NULL, p_source_ts timestamptz DEFAULT NULL, p_target_ts timestamptz DEFAULT NULL)
RETURNS TABLE(account_nbr TEXT, account_code TEXT, account_name CITEXT, facility_nbr JSONB, create_ts timestamptz, update_ts timestamptz) 
AS '
BEGIN
    RETURN QUERY
    SELECT
		ac.account_nbr, ac.account_code, ac.account_name, jsonb_agg(f.facility_nbr) as facility_nbr, ac.create_ts, ac.update_ts
	FROM account ac
	LEFT JOIN facility f on ac.id = f.account_id
	LEFT JOIN userfacility uf on f.id = uf.facility_id
		WHERE 
		(
			(p_source_ts IS NOT NULL AND ac.update_ts >= p_source_ts)
			OR 
			p_source_ts IS NULL
		)
		AND
		(
			(p_target_ts IS NOT NULL AND ac.update_ts <= p_target_ts)
			OR
			p_target_ts IS NULL
		)
		AND
			(uf.user_id = p_user_id OR p_user_id is null)
	GROUP BY ac.account_nbr, ac.account_code, ac.account_name, ac.create_ts, ac.update_ts;
END;
' LANGUAGE plpgsql;
/
CALL drop_functions_by_name('get_account_by_json');
/
-- Stored procedure to get an asset by ID

CREATE OR REPLACE FUNCTION get_account_by_json(p_jsonb jsonb, p_user_id bigint default NULL)
RETURNS TABLE(account_nbr text, account_code text, account_name CITEXT, facility_nbr JSONB, create_ts timestamptz, update_ts timestamptz)
AS '
DECLARE
--	p_jsonb jsonb := ''{
--		"account_nbr": ["ACCT_NBR_10"]
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
		''account_nbr'' as filter, get_jsonb_values_by_key (json_output, ''account_nbr'') as value
		from parsed_keys
		union select 
		''account_code'' as filter, get_jsonb_values_by_key (json_output, ''account_code'') as value
		from parsed_keys
		union select 
		''account_name'' as filter, get_jsonb_values_by_key (json_output, ''account_name'')::CITEXT as value
		from parsed_keys;


	RETURN QUERY
	select 
		acc.account_nbr, acc.account_code, acc.account_name, jsonb_agg(fac.facility_nbr) as facility_nbr, acc.create_ts, acc.update_ts
	FROM account acc
	left join 
		facility fac on acc.id = fac.account_id
	left join 
		userfacility uf on fac.id = uf.facility_id
	WHERE 
		(
		EXISTS (SELECT 1 FROM parsed_values v WHERE v.filter = ''account_nbr'' AND acc.account_nbr = v.value)
		OR (SELECT count(*) FROM parsed_values v WHERE v.filter = ''account_nbr'') = 0
		)
		AND (uf.user_id = p_user_id OR p_user_id is null)
	GROUP BY
		acc.account_nbr, acc.account_code, acc.account_name, acc.create_ts, acc.update_ts;

END;
' LANGUAGE plpgsql;
/
CALL drop_functions_by_name('upsert_account_from_json');
/
CREATE OR REPLACE FUNCTION upsert_account_from_json(
    p_jsonb_in jsonb, p_channel_name TEXT, p_user_id bigint, p_parent_chennel_name TEXT default null
) 
RETURNS TABLE(account_nbr text, account_code text, account_name citext,facility_nbr JSONB, create_ts timestamptz, update_ts timestamptz) AS ' 
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
		p_jsonb ->> ''account_nbr'' AS account_nbr,	    
		p_jsonb ->> ''account_code'' AS account_code,
		p_jsonb ->> ''account_name'' AS account_name
	FROM jsonb_array_elements(p_jsonb_in::JSONB) AS p_jsonb;

	DELETE from temp_json_data t where t.account_nbr IS NULL;

	CREATE TEMP TABLE update_stage AS
	SELECT 
		acc.id as id,
		coalesce(t.account_nbr, acc.account_nbr) as account_nbr, 
		coalesce(t.account_code, acc.account_code) as account_code, 
		coalesce(t.account_name, acc.account_name) as account_name
	FROM	
	temp_json_data t
	left join account acc on t.account_nbr = acc.account_nbr;

	-- remove upserts where the user does not have access to the facility
	IF p_user_id IS NOT NULL THEN

		DELETE FROM update_stage t
		USING facility f
		WHERE t.id = f.account_id 
		AND NOT EXISTS (
			SELECT 1 
			FROM userfacility uf 
			WHERE uf.facility_id = f.id 
			AND uf.user_id = p_user_id
		);

	END IF;

	-- Perform UPSERT: Insert new records or update existing ones
	MERGE INTO account AS target
	USING update_stage AS source
	ON target.account_nbr = source.account_nbr
	WHEN MATCHED THEN
	    UPDATE SET 
	        account_code = source.account_code,
			account_name = source.account_name,
	        update_ts = now()
	WHEN NOT MATCHED THEN
	    INSERT (account_nbr, account_code, account_name, create_ts)
	    VALUES (source.account_nbr, source.account_code, source.account_name, now());

    -- Raise event for consumers
    FOR account_nbr IN
        SELECT acc.account_nbr 
		FROM account acc
		JOIN update_stage t ON acc.account_nbr = t.account_nbr
    LOOP
		INSERT INTO event_notification_buffer(channel, payload, create_ts)
		VALUES (p_channel_name, account_nbr, now());
        PERFORM pg_notify(p_channel_name, account_nbr);
    END LOOP;
	
    -- Return the updated records
    RETURN QUERY 
    SELECT acc.account_nbr, acc.account_code, acc.account_name, jsonb_agg(fac.facility_nbr), acc.create_ts, acc.update_ts
    FROM account acc
	LEFT JOIN facility fac on acc.id = fac.account_id
	JOIN update_stage t ON acc.account_nbr = t.account_nbr
	GROUP BY
		acc.account_nbr, acc.account_code, acc.account_name, acc.create_ts, acc.update_ts;
END;

' LANGUAGE plpgsql;
/
