-- Stored procedure to get all items
CREATE OR REPLACE FUNCTION get_all_assets()
RETURNS TABLE(id INT, asset_id VARCHAR(250), sys_id VARCHAR(250), fac_code VARCHAR(250)) AS $$
BEGIN
    RETURN QUERY
    SELECT asset.id, asset.asset_id, asset.sys_id, facility.fac_code FROM daas.asset asset
    JOIN daas.facility facility on asset.fac_id = facility.id;
END;
$$ LANGUAGE plpgsql;

-- Stored procedure to insert a new item
CREATE OR REPLACE FUNCTION create_asset(new_asset_id VARCHAR(250), new_sys_id VARCHAR(250), new_fac_code VARCHAR(250))
RETURNS TABLE(id INT, asset_id VARCHAR(250), sys_id VARCHAR(250), fac_code VARCHAR(250)) AS $$
DECLARE
    unknown_fac_id INT;
    unknown_fac_code VARCHAR(250);
	calc_fac_id INT;
    calc_fac_code VARCHAR(250);
BEGIN
    SELECT id, fac_code INTO unknown_fac_id, unknown_fac_code
	FROM daas.facility
	WHERE upper(fac_code) = 'UNKNOWN';

    calc_fac_id := COALESCE((SELECT id FROM daas.facility WHERE fac_code = new_fac_code), unknown_fac_id);
  	calc_fac_code := CASE
        WHEN calc_fac_id = unknown_fac_id THEN unknown_fac_code
        ELSE new_fac_code
    END;

    INSERT INTO daas.asset (asset_id, sys_id, fac_id, create_ts)
    VALUES (new_asset_id, new_sys_id, calc_fac_id, NOW())
    RETURNING id, asset_id, sys_id, calc_fac_code;
END;
$$ LANGUAGE plpgsql;

-- Stored procedure to retrieve an asset by ID
CREATE OR REPLACE FUNCTION get_asset_by_id(p_id INT)
RETURNS TABLE(id INT, asset_id VARCHAR(250), sys_id VARCHAR(250), fac_code VARCHAR(250)) AS $$
BEGIN
    RETURN QUERY
    SELECT asset.id, asset.asset_id, asset.sys_id, facility.fac_code 
    FROM daas.asset asset
    JOIN daas.facility facility ON asset.fac_id  = facility.id
    WHERE asset.id = p_id;  
END;
$$ LANGUAGE plpgsql;

-- Stored procedure to update an asset
CREATE OR REPLACE FUNCTION update_asset(p_id INT, new_asset_id VARCHAR(250), new_sys_id VARCHAR(250), new_fac_code VARCHAR(250))
RETURNS VOID AS $$
BEGIN
    UPDATE daas.asset
    SET asset_id = asset_id, sys_id = new_sys_id
    WHERE id = p_id;
END;
$$ LANGUAGE plpgsql;

-- Stored procedure to delete an asset
CREATE OR REPLACE FUNCTION delete_asset(p_id INT)
RETURNS VOID AS $$
BEGIN
    DELETE FROM daas.asset WHERE id = p_id;
END;
$$ LANGUAGE plpgsql;
