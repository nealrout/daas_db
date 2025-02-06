drop table if exists daas.facility;

create table if not exists daas.facility (
    id serial primary key,
    fac_code varchar(250) not null,
    fac_name varchar(250) null,
    create_ts timestamptz null,
    update_ts timestamptz default now()
);
