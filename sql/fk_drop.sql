DO '
BEGIN
    IF EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = ''fk_account_id''
        AND conrelid = ''daas.facility''::regclass
    ) THEN
        ALTER TABLE daas.facility
        DROP CONSTRAINT fk_account_id;
        RAISE NOTICE ''Foreign key constraint fk_account_id has been dropped.'';
    ELSE
        RAISE NOTICE ''Foreign key constraint fk_account_id does not exist.'';
    END IF;
END ';
/
DO '
BEGIN
    IF EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = ''fk_facility_id''
        AND conrelid = ''daas.asset''::regclass
    ) THEN
        ALTER TABLE daas.asset
        DROP CONSTRAINT fk_facility_id;
        RAISE NOTICE ''Foreign key constraint fk_facility_id has been dropped.'';
    ELSE
        RAISE NOTICE ''Foreign key constraint fk_facility_id does not exist.'';
    END IF;
END ';
/
DO '
BEGIN
    IF EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = ''fk_facility_facility_id''
        AND conrelid = ''daas.asset''::regclass
    ) THEN
        ALTER TABLE daas.asset
        DROP CONSTRAINT fk_facility_facility_id;
        RAISE NOTICE ''Foreign key constraint fk_facility_facility_id has been dropped.'';
    ELSE
        RAISE NOTICE ''Foreign key constraint fk_facility_facility_id does not exist.'';
    END IF;
END ';
/
/
DO '
BEGIN
    IF EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = ''fk_facility_id''
        AND conrelid = ''daas.user_facility''::regclass
    ) THEN
        ALTER TABLE daas.user_facility
        DROP CONSTRAINT fk_facility_id;
        RAISE NOTICE ''Foreign key constraint fk_facility_id has been dropped.'';
    ELSE
        RAISE NOTICE ''Foreign key constraint fk_facility_id does not exists.'';
    END IF;
END ';
/
DO '
BEGIN
    IF EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = ''fk_user_id''
        AND conrelid = ''daas.user_facility''::regclass
    ) THEN
        ALTER TABLE daas.user_facility
        DROP CONSTRAINT fk_user_id;
        RAISE NOTICE ''Foreign key constraint fk_user_id has been dropped.'';
    ELSE
        RAISE NOTICE ''Foreign key constraint fk_user_id does not exists.'';
    END IF;
END ';
/
DO '
BEGIN
    IF EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = ''fk_asset_id''
        AND conrelid = ''daas.service''::regclass
    ) THEN
        ALTER TABLE daas.service
        DROP CONSTRAINT fk_asset_id;
        RAISE NOTICE ''Foreign key constraint fk_asset_id has been dropped.'';
    ELSE
        RAISE NOTICE ''Foreign key constraint fk_asset_id does not exists.'';
    END IF;
END ';
/
DO '
BEGIN
    IF EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = ''fk_service_status_status_code''
        AND conrelid = ''daas.service''::regclass
    ) THEN
        ALTER TABLE daas.service
        DROP CONSTRAINT fk_service_status_status_code;
        RAISE NOTICE ''Foreign key constraint fk_service_status_status_code has been dropped.'';
    ELSE
        RAISE NOTICE ''Foreign key constraint fk_service_status_status_code does not exists.'';
    END IF;
END ';
/
DO '
BEGIN
    IF EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = ''fk_asset_status_status_code''
        AND conrelid = ''daas.asset''::regclass
    ) THEN
        ALTER TABLE daas.asset
        DROP CONSTRAINT fk_asset_status_status_code;
        RAISE NOTICE ''Foreign key constraint fk_asset_status_status_code has been dropped.'';
    ELSE
        RAISE NOTICE ''Foreign key constraint fk_asset_status_status_code does not exists.'';
    END IF;
END ';
/
