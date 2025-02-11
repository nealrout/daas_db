drop table if exists daas.service_status;
/
create table if not exists daas.service_status (
    status_code VARCHAR(50) PRIMARY KEY,
    create_ts timestamptz null,
    update_ts timestamptz default now()
);
/
