DO '
BEGIN
    IF EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = ''fk_account_id''
        AND conrelid = (SELECT oid FROM pg_class WHERE relname = ''facility'')
    ) THEN
        ALTER TABLE facility
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
        AND conrelid = (SELECT oid FROM pg_class WHERE relname = ''asset'')
    ) THEN
        ALTER TABLE asset
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
        WHERE conname = ''fk_facility_id''
        AND conrelid = (SELECT oid FROM pg_class WHERE relname = ''userfacility'')
    ) THEN
        ALTER TABLE userfacility
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
        AND conrelid = (SELECT oid FROM pg_class WHERE relname = ''userfacility'')
    ) THEN
        ALTER TABLE userfacility
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
        AND conrelid = (SELECT oid FROM pg_class WHERE relname = ''service'')
    ) THEN
        ALTER TABLE service
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
        AND conrelid = (SELECT oid FROM pg_class WHERE relname = ''service'')
    ) THEN
        ALTER TABLE service
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
        AND conrelid = (SELECT oid FROM pg_class WHERE relname = ''asset'')
    ) THEN
        ALTER TABLE asset
        DROP CONSTRAINT fk_asset_status_status_code;
        RAISE NOTICE ''Foreign key constraint fk_asset_status_status_code has been dropped.'';
    ELSE
        RAISE NOTICE ''Foreign key constraint fk_asset_status_status_code does not exists.'';
    END IF;
END ';
/
DO '
BEGIN
    IF EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = ''fk_index_log_status_code''
        AND conrelid = (SELECT oid FROM pg_class WHERE relname = ''index_log'')
    ) THEN
        ALTER TABLE index_log
        DROP CONSTRAINT fk_index_log_status_code;
        RAISE NOTICE ''Foreign key constraint fk_index_log_status_code has been dropped.'';
    ELSE
        RAISE NOTICE ''Foreign key constraint fk_index_log_status_code does not exists.'';
    END IF;
END ';
/
