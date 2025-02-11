CALL drop_functions_by_name('get_assets');
/
-- Stored procedure to get all items
CREATE OR REPLACE FUNCTION get_assets(p_user_id bigint)
RETURNS TABLE(id BIGINT, asset_id character varying, sys_id character varying, fac_code character varying) AS '
BEGIN
    RETURN QUERY
    SELECT asset.id, asset.asset_id, asset.sys_id, facility.fac_code 
	FROM daas.asset asset
    JOIN daas.facility facility on asset.fac_id = facility.id
	JOIN daas.user_facility uf on facility.id = uf.fac_id
	WHERE uf.user_id = p_user_id;
END;
' LANGUAGE plpgsql;
/
CALL drop_functions_by_name('get_assets_by_id');
/
-- Stored procedure to get an asset by ID
CREATE OR REPLACE FUNCTION daas.get_assets_by_id(p_jsonb jsonb, p_user_id bigint)
RETURNS TABLE(id bigint, asset_id character varying, sys_id character varying, fac_id bigint, fac_code character varying)
AS '
DECLARE
BEGIN
  	RETURN QUERY
	SELECT main.id, main.asset_id, main.sys_id, main.fac_id, main.fac_code
	FROM 
		(
		SELECT sub.id, sub.asset_id, sub.sys_id, sub.fac_id, f.fac_code
		FROM
			(
			SELECT a.id, a.asset_id, a.sys_id, a.fac_id
			FROM get_jsonb_values_by_key (p_jsonb, ''id'') k
			JOIN daas.asset a ON k.value::bigint = a.id
			UNION
			SELECT a.id, a.asset_id, a.sys_id, a.fac_id
			FROM get_jsonb_values_by_key (p_jsonb, ''asset_id'') k
			JOIN daas.asset a ON k.value = a.asset_id
			UNION
			SELECT a.id, a.asset_id, a.sys_id, a.fac_id
			FROM get_jsonb_values_by_key (p_jsonb, ''sys_id'') k
			JOIN daas.asset a ON k.value = a.asset_id
			) sub
		JOIN daas.facility_facility f ON sub.fac_id = f.id
		LEFT JOIN get_jsonb_values_by_key (p_jsonb, ''fac_code'') k 	--json did not include fac_cd
			on f.fac_code = k.value 								
		UNION
		SELECT a.id, a.asset_id, a.sys_id, f.Id, f.fac_code
		FROM daas.asset a
		JOIN daas.facility_facility f on a.fac_id = f.Id
		JOIN get_jsonb_values_by_key (p_jsonb, ''fac_code'') k 		--json did include fac_cd
			on f.fac_code = k.value									
		) main
	JOIN daas.user_facility uf on main.fac_id = uf.fac_id			-- only objects user_id has access to
	WHERE uf.user_id = p_user_id;
END;
' LANGUAGE plpgsql;
/
CALL drop_functions_by_name('asset_upsert_from_json');
/
CREATE OR REPLACE FUNCTION asset_upsert_from_json(
    p_jsonb_in jsonb, p_channel_name TEXT, p_user_id bigint
) 
RETURNS TABLE(id BIGINT, asset_id character varying, sys_id character varying, fac_code character varying) AS ' 
DECLARE
	unknown_fac_id bigint;
BEGIN
	DROP TABLE IF EXISTS temp_json_data;
	CREATE TEMP TABLE temp_json_data (
	    --id BIGINT,
	    asset_id TEXT,
	    sys_id TEXT,
	    fac_code TEXT,
	    fac_id BIGINT
	);

    SELECT f.id INTO unknown_fac_id
    FROM daas.facility_facility f
    WHERE upper(f.fac_code) = ''UNKNOWN'';

	INSERT INTO temp_json_data (asset_id, sys_id, fac_code)
	SELECT 
	    --(p_jsonb ->> ''id'')::bigint AS id,
	    p_jsonb ->> ''asset_id'' AS asset_id,
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
	ON target.asset_id = source.asset_id
	WHEN MATCHED THEN
	    UPDATE SET 
	        --asset_id = source.asset_id,
	        sys_id = source.sys_id,
	        fac_id = source.fac_id,
	        update_ts = now()
	WHEN NOT MATCHED THEN
	    INSERT (asset_id, sys_id, fac_id, update_ts)
	    VALUES (source.asset_id, source.sys_id, source.fac_id, now());

    -- Raise event for consumers
    FOR asset_id IN
        SELECT a.asset_id 
		FROM daas.asset a
		JOIN temp_json_data t ON a.asset_id = t.asset_id
    LOOP
        PERFORM pg_notify(p_channel_name, asset_id);
    END LOOP;
	
    -- Return the updated records
    RETURN QUERY 
    SELECT a.id, a.asset_id, a.sys_id, f.fac_code
    FROM daas.asset a
    JOIN daas.facility_facility f ON a.fac_id = f.id
	JOIN temp_json_data t ON a.asset_id = t.asset_id;
END;

' LANGUAGE plpgsql;
/
