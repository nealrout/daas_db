drop table if exists daas.index_log;

create table if not exists daas.index_log (
    id serial primary key,
    collection_name varchar(250) not null,
    status varchar(250) null,
    description text null,
    create_ts timestamptz null,
    update_ts timestamptz default now()
);