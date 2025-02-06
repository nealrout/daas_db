drop table if exists daas.asset;

create table if not exists daas.asset (
    id serial primary key,
    fac_id int not null,
    asset_id varchar(250) not null,
    sys_id varchar(250) null,
    create_ts timestamptz,
    update_ts timestamptz default now()
);

ALTER TABLE daas.asset
ADD CONSTRAINT unique_asset_id UNIQUE (asset_id);
