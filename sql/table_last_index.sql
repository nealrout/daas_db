drop table if exists last_index;
/
create table if not exists last_index (
    id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    collection_name varchar(250) not null,
    last_index_ts timestamptz null,
    override_ts timestamptz null,
    update_ts timestamptz default now()
);
/