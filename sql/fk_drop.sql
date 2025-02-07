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