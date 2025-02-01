drop table if exists daas.asset;

create table if not exists daas.asset (
    id serial primary key,
    fac_id bigint not null,
    asset_id varchar(250) not null,
    sys_id varchar(250) null,
    create_ts timestamp,
    update_ts timestamp
);

ALTER TABLE daas.asset
ADD CONSTRAINT unique_asset_id UNIQUE (asset_id);
