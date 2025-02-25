CALL drop_procedures_by_name('clean_integration_data');
/
CREATE OR REPLACE PROCEDURE clean_integration_data()
AS '
DECLARE
BEGIN
    DELETE FROM service
    USING asset a
    JOIN facility f ON a.facility_id = f.id
    JOIN account acc ON f.account_id = acc.id
    WHERE service.asset_id = a.id
    AND acc.account_nbr LIKE ''INT_%'';

    DELETE FROM asset
    USING facility f 
    JOIN account acc ON f.account_id = acc.id
    WHERE asset.facility_id = f.id
    AND acc.account_nbr LIKE ''INT_%'';

    DELETE FROM userfacility
    USING facility f 
    JOIN account acc ON f.account_id = acc.id
    WHERE userfacility.facility_id = f.id
    AND acc.account_nbr LIKE ''INT_%'';

    DELETE FROM facility
    USING account acc
    WHERE facility.account_id = acc.id
    AND acc.account_nbr LIKE ''INT_%'';

    DELETE FROM account
    WHERE account_nbr LIKE ''INT_%'';
END; 
' LANGUAGE plpgsql;
/

