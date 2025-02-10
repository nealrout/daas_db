
DO '
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = ''fk_facility''
        AND conrelid = ''daas.asset''::regclass
    ) THEN
        ALTER TABLE daas.asset
        ADD CONSTRAINT fk_facility
        FOREIGN KEY (fac_id) REFERENCES daas.facility(id);
        RAISE NOTICE ''Foreign key constraint fk_facility has been added.'';
    ELSE
        RAISE NOTICE ''Foreign key constraint fk_facility already exists.'';
    END IF;
END ';
/
DO '
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = ''fk_facility_facility''
        AND conrelid = ''daas.asset''::regclass
    ) THEN
        ALTER TABLE daas.asset
        ADD CONSTRAINT fk_facility_facility
        FOREIGN KEY (fac_id) REFERENCES daas.facility_facility(id);
        RAISE NOTICE ''Foreign key constraint fk_facility_facility has been added.'';
    ELSE
        RAISE NOTICE ''Foreign key constraint fk_facility_facility already exists.'';
    END IF;
END ';
/
DO '
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = ''fk_facility''
        AND conrelid = ''daas.user_facility''::regclass
    ) THEN
        ALTER TABLE daas.user_facility
        ADD CONSTRAINT fk_facility
        FOREIGN KEY (fac_id) REFERENCES daas.facility(id);
        RAISE NOTICE ''Foreign key constraint fk_facility has been added.'';
    ELSE
        RAISE NOTICE ''Foreign key constraint fk_facility already exists.'';
    END IF;
END ';
/
DO '
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = ''fk_user''
        AND conrelid = ''daas.user_facility''::regclass
    ) THEN
        ALTER TABLE daas.user_facility
        ADD CONSTRAINT fk_user
        FOREIGN KEY (user_id) REFERENCES daas.auth_user(id);
        RAISE NOTICE ''Foreign key constraint fk_user has been added.'';
    ELSE
        RAISE NOTICE ''Foreign key constraint fk_user already exists.'';
    END IF;
END ';
/