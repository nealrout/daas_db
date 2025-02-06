drop table if exists daas.last_index;

create table if not exists daas.last_index (
    id serial primary key,
    collection_name varchar(250) not null,
    last_index_ts timestamptz null,
    override_ts timestamptz null,
    update_ts timestamptz default now()
);