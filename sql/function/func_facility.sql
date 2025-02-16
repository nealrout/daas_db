CALL drop_functions_by_name('get_facility');
/
-- Stored procedure to get all items
CREATE OR REPLACE FUNCTION get_facility(p_user_id bigint DEFAULT NULL, p_source_ts timestamptz DEFAULT NULL, p_target_ts timestamptz DEFAULT NULL)
RETURNS TABLE(acct_nbr TEXT, fac_nbr TEXT, fac_code TEXT, fac_name CITEXT, create_ts timestamptz, update_ts timestamptz) 
AS '
BEGIN
    RETURN QUERY
    SELECT 
		ac.acct_nbr, f.fac_nbr, f.fac_code, f.fac_name, f.create_ts, f.update_ts
	FROM facility f
	JOIN user_facility uf on f.id = uf.fac_id
	JOIN account ac ON f.acct_id = ac.Id
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
RETURNS TABLE(acct_nbr text, fac_nbr text, fac_code text, fac_name CITEXT, create_ts timestamptz, update_ts timestamptz)
AS '
DECLARE
--	p_jsonb jsonb := ''{
--    "acct_nbr": [
--        "ACCT_NBR_10"
--    ],
--    "fac_code": [
--        "US_TEST_10"
--    ],
--    "fac_name": [
--        "TEST FACILITY 10",
--        "TEST FACILITY 18"
--    ],
--    "fac_nbr": [
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
		''acct_nbr'' as filter, get_jsonb_values_by_key (json_output, ''acct_nbr'') as value
		from parsed_keys
		union select 
		''acct_code'' as filter, get_jsonb_values_by_key (json_output, ''acct_code'') as value
		from parsed_keys
		union select 
		''fac_nbr'' as filter, get_jsonb_values_by_key (json_output, ''fac_nbr'') as value
		from parsed_keys
		union select 
		''fac_code'' as filter, get_jsonb_values_by_key (json_output, ''fac_code'') as value
		from parsed_keys
		union select 
		''fac_name'' as filter, get_jsonb_values_by_key (json_output, ''fac_name'')::CITEXT as value
		from parsed_keys;

--	create table res as select acct.acct_nbr, acct.acct_code, fac.fac_nbr, fac.fac_code, fac.fac_name, fac.create_ts, fac.update_ts 
--	from account acct join facility fac on acct.id = fac.acct_id limit 0;

	RETURN QUERY
	SELECT
		acc.acct_nbr, fac.fac_nbr, fac.fac_code, fac.fac_name, fac.create_ts, fac.update_ts
	FROM account acc
	JOIN facility fac ON acc.id = fac.acct_id 
	JOIN user_facility uf on fac.id = uf.fac_id
	WHERE 
		(
		EXISTS (SELECT 1 FROM parsed_values v WHERE v.FILTER = ''acct_nbr'' AND acc.acct_nbr = v.value)
		OR (SELECT count(*) FROM parsed_values v WHERE v.FILTER = ''acct_nbr'') = 0
		)
		AND
		(
		EXISTS (SELECT 1 FROM parsed_values v WHERE v.FILTER = ''acct_code'' AND acc.acct_code = v.value)
		OR (SELECT count(*) FROM parsed_values v WHERE v.FILTER = ''acct_code'') = 0
		)
		AND
		(
		EXISTS (SELECT 1 FROM parsed_values v WHERE v.FILTER = ''fac_nbr'' AND fac.fac_nbr = v.value)
		OR (SELECT count(*) FROM parsed_values v WHERE v.FILTER = ''fac_nbr'') = 0
		)
		AND
		(
		EXISTS (SELECT 1 FROM parsed_values v WHERE v.FILTER = ''fac_code'' AND fac.fac_code = v.value)
		OR (SELECT count(*) FROM parsed_values v WHERE v.FILTER = ''fac_code'') = 0
		)
		AND
		(
		EXISTS (SELECT 1 FROM parsed_values v WHERE v.FILTER = ''fac_name'' AND fac.fac_name = v.value)
		OR (SELECT count(*) FROM parsed_values v WHERE v.FILTER = ''fac_name'') = 0
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
RETURNS TABLE(acct_nbr text, fac_nbr text, fac_code text, fac_name CITEXT, create_ts timestamptz, update_ts timestamptz) AS ' 
DECLARE
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
		p_jsonb ->> ''acct_nbr'' AS acct_nbr,	    
		p_jsonb ->> ''fac_nbr'' AS fac_nbr,
		p_jsonb ->> ''fac_code'' AS fac_code,
		p_jsonb ->> ''fac_name'' AS fac_name
	FROM jsonb_array_elements(p_jsonb_in::JSONB) AS p_jsonb;

	DELETE from temp_json_data t where t.acct_nbr IS NULL;

	CREATE TEMP TABLE update_stage AS
	SELECT 
		f.id as fac_id,
		coalesce(target_acc.id, acc.id) as target_acct_id,
		coalesce(t.acct_nbr, acc.acct_nbr) as acct_nbr, 
		coalesce(t.fac_nbr, f.fac_nbr) as fac_nbr, 
		coalesce(t.fac_code, f.fac_code) as fac_code, 
		coalesce(t.fac_name, f.fac_name) as fac_name
	FROM	
	temp_json_data t
	left join facility f on t.fac_nbr = f.fac_nbr
	left join account acc on f.acct_id = acc.id
	left join account target_acc on t.acct_nbr = target_acc.acct_nbr;

	-- remove upserts where the user does not have access to the facility
	IF p_user_id IS NOT NULL THEN

		DELETE from update_stage t
		WHERE t.fac_id IS NOT NULL 
			AND	NOT EXISTS (select 1 FROM user_facility uf WHERE t.fac_id = uf.fac_id AND uf.user_id = p_user_id);

	END IF;

	-- Perform UPSERT: Insert new records or update existing ones
	WITH merged as (
		MERGE INTO facility AS target
		USING update_stage AS source
		ON target.fac_nbr = source.fac_nbr
		WHEN MATCHED THEN
			UPDATE SET 
				acct_id = source.target_acct_id,
				fac_code = source.fac_code,
				fac_name = source.fac_name,
				update_ts = now()
		WHEN NOT MATCHED THEN
			INSERT (acct_id, fac_nbr, fac_code, fac_name, create_ts)
			VALUES (source.target_acct_id, source.fac_nbr, source.fac_code, source.fac_name, now())
		RETURNING id
	)
	INSERT INTO user_facility (user_id, fac_id, create_ts)
	SELECT p_user_id, m.id, now() FROM merged m
	LEFT JOIN user_facility uf on m.id = uf.fac_id
	WHERE uf.fac_id IS NULL;

    -- Raise event for consumers
    FOR fac_nbr IN
        SELECT f.fac_nbr 
		FROM facility f
		JOIN update_stage t ON f.fac_nbr = t.fac_nbr
    LOOP
		INSERT INTO event_notification_buffer(channel, payload, create_ts)
		VALUES (p_channel_name, fac_nbr, now());
        PERFORM pg_notify(p_channel_name, fac_nbr);
    END LOOP;
	
    -- Return the updated records
    RETURN QUERY 
    SELECT acc.acct_nbr, f.fac_nbr, f.fac_code, f.fac_name, f.create_ts, f.update_ts
    FROM facility f
	join account acc on f.acct_id = acc.id
	JOIN update_stage t ON f.fac_nbr = t.fac_nbr;
END;
' LANGUAGE plpgsql;
/
