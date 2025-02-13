-- This table is currently not used.  We are using the facility_facility table
-- which is controled by Django migrations.
drop table if exists facility;
/
create table if not exists facility (
    id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    acct_id bigint not null,
    fac_nbr TEXT not null,
    fac_code TEXT not null,
    fac_name TEXT null,
    create_ts timestamptz null,
    update_ts timestamptz default now()
);
/
DROP INDEX IF EXISTS idx_facility_fac_code;
/
CREATE INDEX idx_facility_fac_code ON facility(fac_code) INCLUDE(fac_name);
/
DROP INDEX IF EXISTS idx_facility_update_ts;
/
CREATE INDEX idx_facility_update_ts ON facility(update_ts);
/
DROP INDEX IF EXISTS idx_facility_create_ts;
/
CREATE INDEX idx_facility_create_ts ON facility(create_ts);
/
ALTER TABLE facility
ADD CONSTRAINT unique_fac_nbr UNIQUE (fac_nbr);
/