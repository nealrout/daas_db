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

CREATE OR REPLACE FUNCTION get_account_by_json(p_jsonb jsonb, p_user_id bigint)
RETURNS TABLE(acct_nbr text, acct_code text, acct_name text, create_ts timestamptz, update_ts timestamptz)
AS '
DECLARE
--	p_jsonb jsonb := ''{
--		"acct_nbr": ["ACCT_NBR_10"]
--    }'';
--
--	p_user_id bigint := 2;
BEGIN
	
	drop table if exists parsed_keys;
	drop table if exists parsed_values;

	create temp table parsed_keys as
	select * from iterate_json_keys(p_jsonb);

	create temp table parsed_values as
	select 
		get_jsonb_values_by_key (json_output, ''acct_nbr'') as acct_nbr, 
		get_jsonb_values_by_key (json_output, ''acct_code'') as acct_code, 
		get_jsonb_values_by_key (json_output, ''acct_name'') as acct_name
	from parsed_keys p;

	RETURN QUERY
	with acct_cte_condition as(
		select a.*
		from account a
		join parsed_values v on a.acct_nbr = v.acct_nbr
		union
		select a.*
		from account a
		join parsed_values v on a.acct_nbr = v.acct_code
	),
	acct_cte_no_condition as(
		select a.*
		from account a
	)

	select distinct 
		acct.acct_nbr, acct.acct_code, acct.acct_name, acct.create_ts, acct.update_ts
	from
	(
		select * from acct_cte_condition
		UNION
		select * from acct_cte_no_condition where (select count(*) from acct_cte_condition) = 0
	) as acct
	join facility fac on acct.id = fac.acct_id
	join 
		user_facility uf on fac.id = uf.fac_id
	WHERE
		(uf.user_id = p_user_id OR p_user_id is null);

END;
' LANGUAGE plpgsql;
/
