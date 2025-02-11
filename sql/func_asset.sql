CALL drop_functions_by_name('get_asset');
/
-- Stored procedure to get all items
CREATE OR REPLACE FUNCTION get_asset(p_user_id bigint)
RETURNS TABLE(id BIGINT, asset_nbr character varying, sys_id character varying, fac_code character varying) AS '
BEGIN
    RETURN QUERY
    SELECT asset.id, asset.asset_nbr, asset.sys_id, facility.fac_code 
	FROM daas.asset asset
    JOIN daas.facility facility on asset.fac_id = facility.id
	JOIN daas.user_facility uf on facility.id = uf.fac_id
	WHERE uf.user_id = p_user_id;
END;
' LANGUAGE plpgsql;
/
CALL drop_functions_by_name('get_asset_by_id');
/
-- Stored procedure to get an asset by ID
CREATE OR REPLACE FUNCTION daas.get_asset_by_id(p_jsonb jsonb, p_user_id bigint)
RETURNS TABLE(id bigint, fac_code character varying, asset_nbr character varying, sys_id character varying, create_ts timestamptz, update_ts timestamptz)
AS '
DECLARE
BEGIN
  	RETURN QUERY
	WITH fac_cte_condition as (
		select f.id, f.fac_code
		from daas.facility f
		JOIN get_jsonb_values_by_key (p_jsonb, ''fac_code'') k on f.fac_code = k.value
	),
	fac_cte_no_condition as (
		select f.id, f.fac_code
		from daas.facility f
	),
	asset_cte_condition as (
		select a.id, a.fac_id, a.asset_nbr, a.sys_id, a.create_ts, a.update_ts
		from daas.asset a
		JOIN get_jsonb_values_by_key (p_jsonb, ''asset_nbr'') k on a.asset_nbr = k.value
	),
	asset_cte_no_condition as (
		select a.id, a.fac_id, a.asset_nbr, a.sys_id, a.create_ts, a.update_ts
		from daas.asset a
	)

	select a.id, f.fac_code, a.asset_nbr, a.sys_id, a.create_ts, a.update_ts
	from
	(
		select id, fac_code from fac_cte_condition
		union all
		select id, fac_code from fac_cte_no_condition
		where (select count(*) from fac_cte_condition) = 0
	) f
	join
	(
		select id, fac_id, asset_nbr, sys_id, create_ts, update_ts from asset_cte_condition
		union all
		select id, fac_id, asset_nbr, sys_id, create_ts, update_ts from asset_cte_no_condition
		where (select count(*) from asset_cte_condition) = 0
	) a on f.id = a.fac_id
	join
	daas.user_facility uf on f.id = uf.fac_id;

END;
' LANGUAGE plpgsql;
/
CALL drop_functions_by_name('upsert_asset_from_json');
/
CREATE OR REPLACE FUNCTION upsert_asset_from_json(
    p_jsonb_in jsonb, p_channel_name TEXT, p_user_id bigint
) 
RETURNS TABLE(id BIGINT, asset_nbr character varying, sys_id character varying, fac_code character varying) AS ' 
DECLARE
	unknown_fac_id bigint;
BEGIN
	DROP TABLE IF EXISTS temp_json_data;
	CREATE TEMP TABLE temp_json_data (
	    --id BIGINT,
	    asset_nbr TEXT,
	    sys_id TEXT,
	    fac_code TEXT,
	    fac_id BIGINT
	);

    SELECT f.id INTO unknown_fac_id
    FROM daas.facility_facility f
    WHERE upper(f.fac_code) = ''UNKNOWN'';

	INSERT INTO temp_json_data (asset_nbr, sys_id, fac_code)
	SELECT 
	    --(p_jsonb ->> ''id'')::bigint AS id,
	    p_jsonb ->> ''asset_nbr'' AS asset_nbr,
	    p_jsonb ->> ''sys_id'' AS sys_id,
	    p_jsonb ->> ''fac_code'' AS fac_code
	FROM jsonb_array_elements(p_jsonb_in::JSONB) AS p_jsonb;

	UPDATE temp_json_data
	SET fac_id = COALESCE(daas.facility_facility.id, unknown_fac_id)
	FROM daas.facility_facility
	WHERE UPPER(temp_json_data.fac_code) = UPPER(daas.facility_facility.fac_code);
	
	-- remove upserts where the user does not have access to the facility
	DELETE from temp_json_data t
	WHERE NOT EXISTS (select 1 FROM daas.user_facility uf WHERE t.fac_id = uf.fac_id AND uf.user_id = p_user_id);

	-- Perform UPSERT: Insert new records or update existing ones
	MERGE INTO daas.asset AS target
	USING temp_json_data AS source
	ON target.asset_nbr = source.asset_nbr
	WHEN MATCHED THEN
	    UPDATE SET 
	        --asset_nbr = source.asset_nbr,
	        sys_id = source.sys_id,
	        fac_id = source.fac_id,
	        update_ts = now()
	WHEN NOT MATCHED THEN
	    INSERT (asset_nbr, sys_id, fac_id, update_ts)
	    VALUES (source.asset_nbr, source.sys_id, source.fac_id, now());

    -- Raise event for consumers
    FOR asset_nbr IN
        SELECT a.asset_nbr 
		FROM daas.asset a
		JOIN temp_json_data t ON a.asset_nbr = t.asset_nbr
    LOOP
        PERFORM pg_notify(p_channel_name, asset_nbr);
    END LOOP;
	
    -- Return the updated records
    RETURN QUERY 
    SELECT a.id, a.asset_nbr, a.sys_id, f.fac_code
    FROM daas.asset a
    JOIN daas.facility_facility f ON a.fac_id = f.id
	JOIN temp_json_data t ON a.asset_nbr = t.asset_nbr;
END;

' LANGUAGE plpgsql;
/
