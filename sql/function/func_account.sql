CALL drop_functions_by_name('get_account');
/
-- Stored procedure to get all items
CREATE OR REPLACE FUNCTION get_account(p_user_id bigint DEFAULT NULL, p_source_ts timestamptz DEFAULT NULL, p_target_ts timestamptz DEFAULT NULL)
RETURNS TABLE(acct_nbr TEXT, acct_code TEXT, acct_name CITEXT, fac_nbr JSONB, create_ts timestamptz, update_ts timestamptz) 
AS '
BEGIN
    RETURN QUERY
    SELECT
		ac.acct_nbr, ac.acct_code, ac.acct_name, jsonb_agg(f.fac_nbr) as fac_nbr, ac.create_ts, ac.update_ts
	FROM account ac
	LEFT JOIN facility f on ac.id = f.acct_id
	LEFT JOIN user_facility uf on f.id = uf.fac_id
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
	GROUP BY ac.acct_nbr, ac.acct_code, ac.acct_name, ac.create_ts, ac.update_ts;
END;
' LANGUAGE plpgsql;
/
CALL drop_functions_by_name('get_account_by_json');
/
-- Stored procedure to get an asset by ID

CREATE OR REPLACE FUNCTION get_account_by_json(p_jsonb jsonb, p_user_id bigint default NULL)
RETURNS TABLE(acct_nbr text, acct_code text, acct_name CITEXT, fac_nbr JSONB, create_ts timestamptz, update_ts timestamptz)
AS '
DECLARE
--	p_jsonb jsonb := ''{
--		"acct_nbr": ["ACCT_NBR_10"]
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
		''acct_nbr'' as filter, get_jsonb_values_by_key (json_output, ''acct_nbr'') as value
		from parsed_keys
		union select 
		''acct_code'' as filter, get_jsonb_values_by_key (json_output, ''acct_code'') as value
		from parsed_keys
		union select 
		''acct_name'' as filter, get_jsonb_values_by_key (json_output, ''acct_name'')::CITEXT as value
		from parsed_keys;


	RETURN QUERY
	select 
		acc.acct_nbr, acc.acct_code, acc.acct_name, jsonb_agg(fac.fac_nbr) as fac_nbr, acc.create_ts, acc.update_ts
	FROM account acc
	left join 
		facility fac on acc.id = fac.acct_id
	left join 
		user_facility uf on fac.id = uf.fac_id
	WHERE 
		(
		EXISTS (SELECT 1 FROM parsed_values v WHERE v.filter = ''acct_nbr'' AND acc.acct_nbr = v.value)
		OR (SELECT count(*) FROM parsed_values v WHERE v.filter = ''acct_nbr'') = 0
		)
		AND (uf.user_id = p_user_id OR p_user_id is null)
	GROUP BY
		acc.acct_nbr, acc.acct_code, acc.acct_name, acc.create_ts, acc.update_ts;

END;
' LANGUAGE plpgsql;
/
CALL drop_functions_by_name('upsert_account_from_json');
/
CREATE OR REPLACE FUNCTION upsert_account_from_json(
    p_jsonb_in jsonb, p_channel_name TEXT, p_user_id bigint
) 
RETURNS TABLE(acct_nbr text, acct_code text, acct_name citext,fac_nbr JSONB, create_ts timestamptz, update_ts timestamptz) AS ' 
DECLARE
BEGIN
	-- These drop statements are not required when deployed (they auto drop when out of scope).
	-- These are here to help when needing to test in a local session.
	drop table if exists temp_json_data;
	drop table if exists update_stage;

	CREATE TEMP TABLE temp_json_data AS
	SELECT 
		p_jsonb ->> ''acct_nbr'' AS acct_nbr,	    
		p_jsonb ->> ''acct_code'' AS acct_code,
		p_jsonb ->> ''acct_name'' AS acct_name
	FROM jsonb_array_elements(p_jsonb_in::JSONB) AS p_jsonb;

	DELETE from temp_json_data t where t.acct_nbr IS NULL;

	CREATE TEMP TABLE update_stage AS
	SELECT 
		acc.id as id,
		coalesce(t.acct_nbr, acc.acct_nbr) as acct_nbr, 
		coalesce(t.acct_code, acc.acct_code) as acct_code, 
		coalesce(t.acct_name, acc.acct_name) as acct_name
	FROM	
	temp_json_data t
	left join account acc on t.acct_nbr = acc.acct_nbr;

	-- remove upserts where the user does not have access to the facility
	IF p_user_id IS NOT NULL THEN

		DELETE FROM update_stage t
		USING facility f
		WHERE t.id = f.acct_id 
		AND NOT EXISTS (
			SELECT 1 
			FROM user_facility uf 
			WHERE uf.fac_id = f.id 
			AND uf.user_id = p_user_id
		);

	END IF;

	-- Perform UPSERT: Insert new records or update existing ones
	MERGE INTO account AS target
	USING update_stage AS source
	ON target.acct_nbr = source.acct_nbr
	WHEN MATCHED THEN
	    UPDATE SET 
	        acct_code = source.acct_code,
			acct_name = source.acct_name,
	        update_ts = now()
	WHEN NOT MATCHED THEN
	    INSERT (acct_nbr, acct_code, acct_name, create_ts)
	    VALUES (source.acct_nbr, source.acct_code, source.acct_name, now());

    -- Raise event for consumers
    FOR acct_nbr IN
        SELECT acc.acct_nbr 
		FROM account acc
		JOIN update_stage t ON acc.acct_nbr = t.acct_nbr
    LOOP
		INSERT INTO event_notification_buffer(channel, payload, create_ts)
		VALUES (p_channel_name, acct_nbr, now());
        PERFORM pg_notify(p_channel_name, acct_nbr);
    END LOOP;
	
    -- Return the updated records
    RETURN QUERY 
    SELECT acc.acct_nbr, acc.acct_code, acc.acct_name, jsonb_agg(fac.fac_nbr), acc.create_ts, acc.update_ts
    FROM account acc
	LEFT JOIN facility fac on acc.fac_id = fac.id
	JOIN update_stage t ON acc.acct_nbr = t.acct_nbr
	GROUP BY
		acc.acct_nbr, acc.acct_code, acc.acct_name, acc.create_ts, acc.update_ts;
END;

' LANGUAGE plpgsql;
/
