drop table if exists service_status;
/
create table if not exists service_status (
    status_code CITEXT PRIMARY KEY,
    create_ts timestamptz null,
    update_ts timestamptz default now()
);
/
