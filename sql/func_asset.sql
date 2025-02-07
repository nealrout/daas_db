CALL drop_functions_by_name('get_assets');
/
-- Stored procedure to get all items
CREATE OR REPLACE FUNCTION get_assets()
RETURNS TABLE(id INT, asset_id VARCHAR(250), sys_id VARCHAR(250), fac_code VARCHAR(250)) AS '
BEGIN
    RETURN QUERY
    SELECT asset.id, asset.asset_id, asset.sys_id, facility.fac_code FROM daas.asset asset
    JOIN daas.facility_facility facility on asset.fac_id = facility.id;
END;
' LANGUAGE plpgsql;
/
CALL drop_functions_by_name('get_assets_by_id');
/
-- Stored procedure to get an asset by ID
CREATE OR REPLACE FUNCTION daas.get_assets_by_id(p_jsonb jsonb)
RETURNS TABLE(id integer, asset_id character varying, sys_id character varying, fac_code character varying)
AS '
DECLARE
BEGIN
  	RETURN QUERY
	SELECT sub.id, sub.asset_id, sub.sys_id, f.fac_code
	FROM
	(
	SELECT a.id, a.asset_id, a.sys_id, a.fac_id
	FROM get_jsonb_values_by_key (p_jsonb, ''id'') k
	JOIN daas.asset a ON k.value::int = a.id
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
	LEFT JOIN get_jsonb_values_by_key (p_jsonb, ''fac_code'') k on f.fac_code = k.value
	UNION
	SELECT a.id, a.asset_id, a.sys_id, f.fac_code
	FROM daas.asset a
	JOIN daas.facility_facility f on a.fac_id = f.Id
	JOIN get_jsonb_values_by_key (p_jsonb, ''fac_code'') k on f.fac_code = k.value;
END;
' LANGUAGE plpgsql;
/
CALL drop_functions_by_name('asset_upsert_from_json');
/
CREATE OR REPLACE FUNCTION asset_upsert_from_json(
    p_jsonb_in jsonb
) 
RETURNS TABLE(id INT, asset_id VARCHAR(250), sys_id VARCHAR(250), fac_code VARCHAR(250)) AS ' 
DECLARE
	unknown_fac_id integer;
BEGIN
	CREATE TEMP TABLE temp_json_data (
	    id INT,
	    asset_id TEXT,
	    sys_id TEXT,
	    fac_code TEXT,
	    fac_id INT
	);

    SELECT f.id INTO unknown_fac_id
    FROM daas.facility_facility f
    WHERE upper(f.fac_code) = ''UNKNOWN'';

	INSERT INTO temp_json_data (id, asset_id, sys_id, fac_code)
	SELECT 
	    (p_jsonb ->> ''id'')::INT AS id,
	    p_jsonb ->> ''asset_id'' AS asset_id,
	    p_jsonb ->> ''sys_id'' AS sys_id,
	    p_jsonb ->> ''fac_code'' AS fac_code
	FROM jsonb_array_elements(p_jsonb_in::JSONB) AS p_jsonb;

	UPDATE temp_json_data
	SET fac_id = COALESCE(daas.facility_facility.id, unknown_fac_id)
	FROM daas.facility_facility
	WHERE UPPER(temp_json_data.fac_code) = UPPER(daas.facility_facility.fac_code);
	

	-- Perform UPSERT: Insert new records or update existing ones
	MERGE INTO daas.asset AS target
	USING temp_json_data AS source
	ON target.id = source.id
	WHEN MATCHED THEN
	    UPDATE SET 
	        asset_id = source.asset_id,
	        sys_id = source.sys_id,
	        fac_id = source.fac_id,
	        update_ts = now()
	WHEN NOT MATCHED THEN
	    INSERT (asset_id, sys_id, fac_id, update_ts)
	    VALUES (source.asset_id, source.sys_id, source.fac_id, now());

    -- Return the updated records
    RETURN QUERY 
    SELECT a.id, a.asset_id, a.sys_id, f.fac_code
    FROM daas.asset a
    JOIN daas.facility_facility f ON a.fac_id = f.id
	JOIN temp_json_data t ON a.id = t.id;
END;

' LANGUAGE plpgsql;
/
