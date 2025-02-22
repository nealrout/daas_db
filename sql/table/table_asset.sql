drop table if exists asset;
/
create table if not exists asset (
    id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    facility_id int not null,
    asset_nbr TEXT not null,
    asset_code TEXT null,
    sys_id TEXT null,
    status_code CITEXT not null default 'UNKNOWN',
    create_ts timestamptz,
    update_ts timestamptz default now()
);
/
ALTER TABLE asset
ADD CONSTRAINT unique_asset_nbr UNIQUE (asset_nbr);
/
DROP INDEX IF EXISTS idx_asset_asset_nbr;
/
CREATE INDEX idx_asset_asset_nbr ON asset(asset_nbr, status_code);
/
DROP INDEX IF EXISTS idx_asset_sys_id;
/
CREATE INDEX idx_asset_sys_id ON asset(sys_id, status_code);
/
DROP INDEX IF EXISTS idx_asset_update_ts;
/
CREATE INDEX idx_asset_update_ts ON asset(update_ts);
/
DROP INDEX IF EXISTS idx_asset_create_ts;
/
CREATE INDEX idx_asset_create_ts ON asset(create_ts);
/