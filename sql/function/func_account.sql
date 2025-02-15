CALL drop_functions_by_name('acct_code');
/
-- Stored procedure to get all items
CREATE OR REPLACE FUNCTION get_account(p_user_id bigint)
RETURNS TABLE(acct_nbr TEXT, acct_code TEXT, acct_name TEXT, create_ts timestamptz, update_ts timestamptz) 
AS '
BEGIN
    RETURN QUERY
    SELECT DISTINCT
		ac.acct_nbr, ac.acct_code, ac.acct_name, ac.create_ts, ac.update_ts
	FROM account ac
	JOIN facility f on ac.id = f.acct_id
	JOIN user_facility uf on f.id = uf.fac_id
	WHERE 
		(uf.user_id = p_user_id OR p_user_id is null);
END;
' LANGUAGE plpgsql;
/
CALL drop_functions_by_name('get_account_by_json');
/
-- Stored procedure to get an asset by ID

CREATE OR REPLACE FUNCTION get_account_by_json(p_jsonb jsonb, p_user_id bigint default NULL)
RETURNS TABLE(acct_nbr text, acct_code text, acct_name CITEXT, create_ts timestamptz, update_ts timestamptz)
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
	select distinct 
		acc.acct_nbr, acc.acct_code, acc.acct_name, acc.create_ts, acc.update_ts
	FROM account acc
	join 
		facility fac on acc.id = fac.acct_id
	join 
		user_facility uf on fac.id = uf.fac_id
	WHERE 
		(
		EXISTS (SELECT 1 FROM parsed_values v WHERE v.filter = ''acct_nbr'' AND acc.acct_nbr = v.value)
		OR (SELECT count(*) FROM parsed_values v WHERE v.filter = ''acct_nbr'') = 0
		)
		AND (uf.user_id = p_user_id OR p_user_id is null);

END;
' LANGUAGE plpgsql;
/
