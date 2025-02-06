CALL drop_functions_by_name('upsert_assets_from_json');
/
CREATE OR REPLACE FUNCTION upsert_assets_from_json(json_string TEXT)
RETURNS INTEGER AS '
DECLARE
    asset_record JSONB;
    asset JSONB;
	unknown_fac_id int;
	calc_fac_id int;
    rows_affected INTEGER := 0;
	/* TEST INPUT
	json_string TEXT := ''[
    {"fac_code": "US_TEST_99", "asset_id": "asset_30", "sys_id": "system_30"},
    {"fac_code": "US_TEST_02", "asset_id": "asset_31", "sys_id": "system_31"},
    {"fac_code": "US_TEST_03", "asset_id": "asset_32", "sys_id": "system_32"}
	]'';
	*/
BEGIN
--	RAISE NOTICE ''Assets JSON: %'', json_string;

	SELECT id INTO unknown_fac_id
	FROM daas.facility
	WHERE upper(fac_code) = ''UNKNOWN'';
	
--	RAISE NOTICE ''unknown_fac_id: %'', unknown_fac_id;

	
    FOR asset_record IN SELECT * FROM jsonb_array_elements_text(json_string::jsonb)
    LOOP
        asset := asset_record::jsonb;
    	RAISE NOTICE ''asset: %'', asset;
    
    	calc_fac_id := coalesce((SELECT id FROM daas.facility WHERE fac_code = asset->>''fac_code''), unknown_fac_id);
    
        -- Insert into the assets table with facility_id lookup
        INSERT INTO daas.asset (fac_id, asset_id, sys_id, create_ts)
        VALUES (
        	calc_fac_id,    
	        asset->>''asset_id'',
            asset->>''sys_id'',
            now())
        ON CONFLICT (asset_id)
        DO UPDATE SET  
        	fac_id = calc_fac_id,  
        	sys_id = EXCLUDED.sys_id,
        	update_ts = now();
        rows_affected := rows_affected + 1;
    END LOOP;
    RETURN rows_affected;
END; 
' LANGUAGE plpgsql;
/
