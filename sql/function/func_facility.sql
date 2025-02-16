CALL drop_functions_by_name('get_facility');
/
-- Stored procedure to get all items
CREATE OR REPLACE FUNCTION get_facility(p_user_id bigint)
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