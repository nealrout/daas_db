-- This table is currently not used.  We are using the facility_facility table
-- which is controled by Django migrations.
drop table if exists facility;
/
create table if not exists facility (
    id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    account_id bigint not null,
    facility_nbr TEXT not null,
    facility_code TEXT null,
    facility_name CITEXT null,
    create_ts timestamptz null,
    update_ts timestamptz default now()
);
/
ALTER TABLE facility
ADD CONSTRAINT unique_facility_nbr UNIQUE (facility_nbr);
/
DROP INDEX IF EXISTS idx_facility_facility_nbr;
/
CREATE INDEX idx_facility_facility_nbr ON facility(facility_nbr) INCLUDE(facility_name);
/
DROP INDEX IF EXISTS idx_facility_update_ts;
/
CREATE INDEX idx_facility_update_ts ON facility(update_ts);
/
DROP INDEX IF EXISTS idx_facility_create_ts;
/
CREATE INDEX idx_facility_create_ts ON facility(create_ts);
/