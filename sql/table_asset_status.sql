drop table if exists asset_status;
/
create table if not exists asset_status (
    status_code TEXT PRIMARY KEY,
    create_ts timestamptz null,
    update_ts timestamptz default now()
);
/
