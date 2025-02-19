CALL drop_functions_by_name('get_facility');
/
-- Stored procedure to get all items
CREATE OR REPLACE FUNCTION get_facility(p_user_id bigint DEFAULT NULL, p_source_ts timestamptz DEFAULT NULL, p_target_ts timestamptz DEFAULT NULL)
RETURNS TABLE(account_nbr TEXT, facility_nbr TEXT, facility_code TEXT, facility_name CITEXT, create_ts timestamptz, update_ts timestamptz) 
AS '
BEGIN
    RETURN QUERY
    SELECT 
		ac.account_nbr, f.facility_nbr, f.facility_code, f.facility_name, f.create_ts, f.update_ts
	FROM facility f
	JOIN user_facility uf on f.id = uf.facility_id
	JOIN account ac ON f.account_id = ac.Id
	WHERE 
		(
			(p_source_ts IS NOT NULL AND f.update_ts >= p_source_ts)
			OR 
			p_source_ts IS NULL
		)
		AND
		(
			(p_target_ts IS NOT NULL AND f.update_ts <= p_target_ts)
			OR
			p_target_ts IS NULL
		)
		AND
			(uf.user_id = p_user_id OR p_user_id is null);
END;
' LANGUAGE plpgsql;
/
CALL drop_functions_by_name('get_facility_by_json');
/
-- Stored procedure to get an asset by ID

CREATE OR REPLACE FUNCTION get_facility_by_json(p_jsonb jsonb, p_user_id bigint default null)
RETURNS TABLE(account_nbr text, facility_nbr text, facility_code text, facility_name CITEXT, create_ts timestamptz, update_ts timestamptz)
AS '
DECLARE
--	p_jsonb jsonb := ''{
--    "account_nbr": [
--        "ACCT_NBR_10"
--    ],
--    "facility_code": [
--        "US_TEST_10"
--    ],
--    "facility_name": [
--        "TEST FACILITY 10",
--        "TEST FACILITY 18"
--    ],
--    "facility_nbr": [
--        "FAC_NBR_10",
--        "FAC_NBR_02"
--    ]
--}'';
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
		''facility_nbr'' as filter, get_jsonb_values_by_key (json_output, ''facility_nbr'') as value
		from parsed_keys
		union select 
		''facility_code'' as filter, get_jsonb_values_by_key (json_output, ''facility_code'') as value
		from parsed_keys
		union select 
		''facility_name'' as filter, get_jsonb_values_by_key (json_output, ''facility_name'')::CITEXT as value
		from parsed_keys;

--	create table res as select acct.account_nbr, acct.account_code, fac.facility_nbr, fac.facility_code, fac.facility_name, fac.create_ts, fac.update_ts 
--	from account acct join facility fac on acct.id = fac.account_id limit 0;

	RETURN QUERY
	SELECT
		acc.account_nbr, fac.facility_nbr, fac.facility_code, fac.facility_name, fac.create_ts, fac.update_ts
	FROM account acc
	JOIN facility fac ON acc.id = fac.account_id 
	JOIN user_facility uf on fac.id = uf.facility_id
	WHERE 
		(
		EXISTS (SELECT 1 FROM parsed_values v WHERE v.FILTER = ''account_nbr'' AND acc.account_nbr = v.value)
		OR (SELECT count(*) FROM parsed_values v WHERE v.FILTER = ''account_nbr'') = 0
		)
		AND
		(
		EXISTS (SELECT 1 FROM parsed_values v WHERE v.FILTER = ''account_code'' AND acc.account_code = v.value)
		OR (SELECT count(*) FROM parsed_values v WHERE v.FILTER = ''account_code'') = 0
		)
		AND
		(
		EXISTS (SELECT 1 FROM parsed_values v WHERE v.FILTER = ''facility_nbr'' AND fac.facility_nbr = v.value)
		OR (SELECT count(*) FROM parsed_values v WHERE v.FILTER = ''facility_nbr'') = 0
		)
		AND
		(
		EXISTS (SELECT 1 FROM parsed_values v WHERE v.FILTER = ''facility_code'' AND fac.facility_code = v.value)
		OR (SELECT count(*) FROM parsed_values v WHERE v.FILTER = ''facility_code'') = 0
		)
		AND
		(
		EXISTS (SELECT 1 FROM parsed_values v WHERE v.FILTER = ''facility_name'' AND fac.facility_name = v.value)
		OR (SELECT count(*) FROM parsed_values v WHERE v.FILTER = ''facility_name'') = 0
		)
		AND (uf.user_id = p_user_id OR p_user_id is null);
		
END;
' LANGUAGE plpgsql;
/
CALL drop_functions_by_name('upsert_facility_from_json');
/
CREATE OR REPLACE FUNCTION upsert_facility_from_json(
    p_jsonb_in jsonb, p_channel_name TEXT, p_user_id bigint
) 
RETURNS TABLE(account_nbr text, facility_nbr text, facility_code text, facility_name CITEXT, create_ts timestamptz, update_ts timestamptz) AS ' 
DECLARE
	v_unknown_account_id bigint := (select id from account acc where acc.account_nbr = ''UNKNOWN'');
BEGIN
	IF p_user_id IS NULL THEN
		RETURN;
	END IF;

	-- These drop statements are not required when deployed (they auto drop when out of scope).
	-- These are here to help when needing to test in a local session.
	drop table if exists temp_json_data;
	drop table if exists update_stage;

	CREATE TEMP TABLE temp_json_data AS
	SELECT 
		p_jsonb ->> ''account_nbr'' AS account_nbr,	    
		p_jsonb ->> ''facility_nbr'' AS facility_nbr,
		p_jsonb ->> ''facility_code'' AS facility_code,
		p_jsonb ->> ''facility_name'' AS facility_name
	FROM jsonb_array_elements(p_jsonb_in::JSONB) AS p_jsonb;

	DELETE from temp_json_data t where t.account_nbr IS NULL;

	CREATE TEMP TABLE update_stage AS
	SELECT 
		f.id as facility_id,
		coalesce(target_acc.id, acc.id, v_unknown_account_id) as target_account_id,
		coalesce(t.account_nbr, acc.account_nbr) as account_nbr, 
		coalesce(t.facility_nbr, f.facility_nbr) as facility_nbr, 
		coalesce(t.facility_code, f.facility_code) as facility_code, 
		coalesce(t.facility_name, f.facility_name) as facility_name
	FROM	
	temp_json_data t
	left join facility f on t.facility_nbr = f.facility_nbr
	left join account acc on f.account_id = acc.id
	left join account target_acc on t.account_nbr = target_acc.account_nbr;

	-- remove upserts where the user does not have access to the facility
	IF p_user_id IS NOT NULL THEN

		DELETE from update_stage t
		WHERE t.facility_id IS NOT NULL 
			AND	NOT EXISTS (select 1 FROM user_facility uf WHERE t.facility_id = uf.facility_id AND uf.user_id = p_user_id);

	END IF;

	-- Perform UPSERT: Insert new records or update existing ones
	WITH merged as (
		MERGE INTO facility AS target
		USING update_stage AS source
		ON target.facility_nbr = source.facility_nbr
		WHEN MATCHED THEN
			UPDATE SET 
				account_id = source.target_account_id,
				facility_code = source.facility_code,
				facility_name = source.facility_name,
				update_ts = now()
		WHEN NOT MATCHED THEN
			INSERT (account_id, facility_nbr, facility_code, facility_name, create_ts)
			VALUES (source.target_account_id, source.facility_nbr, source.facility_code, source.facility_name, now())
		RETURNING id
	)
	INSERT INTO user_facility (user_id, facility_id, create_ts)
	SELECT p_user_id, m.id, now() FROM merged m
	LEFT JOIN user_facility uf on m.id = uf.facility_id
	WHERE uf.facility_id IS NULL;

    -- Raise event for consumers
    FOR facility_nbr IN
        SELECT f.facility_nbr 
		FROM facility f
		JOIN update_stage t ON f.facility_nbr = t.facility_nbr
    LOOP
		INSERT INTO event_notification_buffer(channel, payload, create_ts)
		VALUES (p_channel_name, facility_nbr, now());
        PERFORM pg_notify(p_channel_name, facility_nbr);
    END LOOP;
	
    -- Return the updated records
    RETURN QUERY 
    SELECT acc.account_nbr, f.facility_nbr, f.facility_code, f.facility_name, f.create_ts, f.update_ts
    FROM facility f
	join account acc on f.account_id = acc.id
	JOIN update_stage t ON f.facility_nbr = t.facility_nbr;
END;
' LANGUAGE plpgsql;
/
