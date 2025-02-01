drop table if exists daas.facility;

create table if not exists daas.facility (
    id serial primary key,
    fac_code varchar(250) not null,
    fac_name varchar(250) null,
    create_ts timestamp null,
    update_ts timestamp null
);
