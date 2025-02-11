drop table if exists service_status;
/
create table if not exists service_status (
    status_code VARCHAR(50) PRIMARY KEY,
    create_ts timestamptz null,
    update_ts timestamptz default now()
);
/
DROP INDEX IF EXISTS idx_service_service_code;
/
CREATE INDEX idx_service_service_code ON service(service_code, status_code) INCLUDE (service_name);
/
DROP INDEX IF EXISTS idx_service_update_ts;
/
CREATE INDEX idx_service_update_ts ON service(update_ts);
/
DROP INDEX IF EXISTS idx_service_create_ts;
/
CREATE INDEX idx_service_create_ts ON service(create_ts);
/