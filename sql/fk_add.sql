DO '
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = ''fk_account_id''
        AND conrelid = (SELECT oid FROM pg_class WHERE relname = ''facility'')
    ) THEN
        ALTER TABLE facility
        ADD CONSTRAINT fk_account_id
        FOREIGN KEY (acct_id) REFERENCES account(id);
        RAISE NOTICE ''Foreign key constraint fk_account_id has been added.'';
    ELSE
        RAISE NOTICE ''Foreign key constraint fk_account_id already exists.'';
    END IF;
END ';
/
DO '
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = ''fk_facility_id''
        AND conrelid = (SELECT oid FROM pg_class WHERE relname = ''asset'')
    ) THEN
        ALTER TABLE asset
        ADD CONSTRAINT fk_facility_id
        FOREIGN KEY (fac_id) REFERENCES facility(id);
        RAISE NOTICE ''Foreign key constraint fk_facility_id has been added.'';
    ELSE
        RAISE NOTICE ''Foreign key constraint fk_facility_id already exists.'';
    END IF;
END ';
/
DO '
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = ''fk_facility_facility_id''
        AND conrelid = (SELECT oid FROM pg_class WHERE relname = ''asset'')
    ) THEN
        ALTER TABLE asset
        ADD CONSTRAINT fk_facility_facility_id
        FOREIGN KEY (fac_id) REFERENCES facility_facility(id);
        RAISE NOTICE ''Foreign key constraint fk_facility_facility_id has been added.'';
    ELSE
        RAISE NOTICE ''Foreign key constraint fk_facility_facility_id already exists.'';
    END IF;
END ';
/
DO '
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = ''fk_facility_id''
        AND conrelid = (SELECT oid FROM pg_class WHERE relname = ''user_facility'')
    ) THEN
        ALTER TABLE user_facility
        ADD CONSTRAINT fk_facility_id
        FOREIGN KEY (fac_id) REFERENCES facility(id);
        RAISE NOTICE ''Foreign key constraint fk_facility_id has been added.'';
    ELSE
        RAISE NOTICE ''Foreign key constraint fk_facility_id already exists.'';
    END IF;
END ';
/
DO '
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = ''fk_user_id''
        AND conrelid = (SELECT oid FROM pg_class WHERE relname = ''user_facility'')
    ) THEN
        ALTER TABLE user_facility
        ADD CONSTRAINT fk_user_id
        FOREIGN KEY (user_id) REFERENCES auth_user(id);
        RAISE NOTICE ''Foreign key constraint fk_user_id has been added.'';
    ELSE
        RAISE NOTICE ''Foreign key constraint fk_user_id already exists.'';
    END IF;
END ';
/
DO '
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = ''fk_asset_id''
        AND conrelid = (SELECT oid FROM pg_class WHERE relname = ''service'')
    ) THEN
        ALTER TABLE service
        ADD CONSTRAINT fk_asset_id
        FOREIGN KEY (asset_id) REFERENCES asset(id);
        RAISE NOTICE ''Foreign key constraint fk_asset_id has been added.'';
    ELSE
        RAISE NOTICE ''Foreign key constraint fk_asset_id already exists.'';
    END IF;
END ';
/
DO '
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = ''fk_service_status_status_code''
        AND conrelid = (SELECT oid FROM pg_class WHERE relname = ''service'')
    ) THEN
        ALTER TABLE service
        ADD CONSTRAINT fk_service_status_status_code
        FOREIGN KEY (status_code) REFERENCES service_status(status_code);
        RAISE NOTICE ''Foreign key constraint fk_service_status_status_code has been added.'';
    ELSE
        RAISE NOTICE ''Foreign key constraint fk_service_status_status_code already exists.'';
    END IF;
END ';
/
DO '
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = ''fk_asset_status_status_code''
        AND conrelid = (SELECT oid FROM pg_class WHERE relname = ''asset'')
    ) THEN
        ALTER TABLE asset
        ADD CONSTRAINT fk_asset_status_status_code
        FOREIGN KEY (status_code) REFERENCES asset_status(status_code);
        RAISE NOTICE ''Foreign key constraint fk_asset_status_status_code has been added.'';
    ELSE
        RAISE NOTICE ''Foreign key constraint fk_asset_status_status_code already exists.'';
    END IF;
END ';
/