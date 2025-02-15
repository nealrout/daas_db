drop table if exists index_status;
/
create table if not exists index_status (
    status_code CITEXT PRIMARY KEY,
    create_ts timestamptz null,
    update_ts timestamptz default now()
);
/
