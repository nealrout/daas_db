DO '
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = ''fk_account_id''
        AND conrelid = ''daas.facility''::regclass
    ) THEN
        ALTER TABLE daas.facility
        ADD CONSTRAINT fk_account_id
        FOREIGN KEY (acct_id) REFERENCES daas.account(id);
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
        AND conrelid = ''daas.asset''::regclass
    ) THEN
        ALTER TABLE daas.asset
        ADD CONSTRAINT fk_facility_id
        FOREIGN KEY (fac_id) REFERENCES daas.facility(id);
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
        AND conrelid = ''daas.asset''::regclass
    ) THEN
        ALTER TABLE daas.asset
        ADD CONSTRAINT fk_facility_facility_id
        FOREIGN KEY (fac_id) REFERENCES daas.facility_facility(id);
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
        AND conrelid = ''daas.user_facility''::regclass
    ) THEN
        ALTER TABLE daas.user_facility
        ADD CONSTRAINT fk_facility_id
        FOREIGN KEY (fac_id) REFERENCES daas.facility(id);
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
        AND conrelid = ''daas.user_facility''::regclass
    ) THEN
        ALTER TABLE daas.user_facility
        ADD CONSTRAINT fk_user_id
        FOREIGN KEY (user_id) REFERENCES daas.auth_user(id);
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
        AND conrelid = ''daas.service''::regclass
    ) THEN
        ALTER TABLE daas.service
        ADD CONSTRAINT fk_asset_id
        FOREIGN KEY (asset_id) REFERENCES daas.asset(id);
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
        AND conrelid = ''daas.service''::regclass
    ) THEN
        ALTER TABLE daas.service
        ADD CONSTRAINT fk_service_status_status_code
        FOREIGN KEY (status_code) REFERENCES daas.service_status(status_code);
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
        AND conrelid = ''daas.asset''::regclass
    ) THEN
        ALTER TABLE daas.asset
        ADD CONSTRAINT fk_asset_status_status_code
        FOREIGN KEY (status_code) REFERENCES daas.asset_status(status_code);
        RAISE NOTICE ''Foreign key constraint fk_asset_status_status_code has been added.'';
    ELSE
        RAISE NOTICE ''Foreign key constraint fk_asset_status_status_code already exists.'';
    END IF;
END ';
/