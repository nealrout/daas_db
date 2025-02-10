DO '
BEGIN
    IF EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = ''fk_facility''
        AND conrelid = ''daas.asset''::regclass
    ) THEN
        ALTER TABLE daas.asset
        DROP CONSTRAINT fk_facility;
        RAISE NOTICE ''Foreign key constraint fk_facility has been dropped.'';
    ELSE
        RAISE NOTICE ''Foreign key constraint fk_facility does not exist.'';
    END IF;
END ';
/
DO '
BEGIN
    IF EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = ''fk_facility_facility''
        AND conrelid = ''daas.asset''::regclass
    ) THEN
        ALTER TABLE daas.asset
        DROP CONSTRAINT fk_facility_facility;
        RAISE NOTICE ''Foreign key constraint fk_facility_facility has been dropped.'';
    ELSE
        RAISE NOTICE ''Foreign key constraint fk_facility_facility does not exist.'';
    END IF;
END ';
/
/
DO '
BEGIN
    IF EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = ''fk_facility''
        AND conrelid = ''daas.user_facility''::regclass
    ) THEN
        ALTER TABLE daas.user_facility
        DROP CONSTRAINT fk_facility;
        RAISE NOTICE ''Foreign key constraint fk_facility has been added.'';
    ELSE
        RAISE NOTICE ''Foreign key constraint fk_facility already exists.'';
    END IF;
END ';
/
DO '
BEGIN
    IF EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = ''fk_user''
        AND conrelid = ''daas.user_facility''::regclass
    ) THEN
        ALTER TABLE daas.user_facility
        DROP CONSTRAINT fk_user;
        RAISE NOTICE ''Foreign key constraint fk_user has been added.'';
    ELSE
        RAISE NOTICE ''Foreign key constraint fk_user already exists.'';
    END IF;
END ';
/