
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

