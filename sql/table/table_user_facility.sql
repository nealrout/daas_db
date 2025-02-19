drop table if exists user_facility;
/
create table if not exists user_facility (
    id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    user_id BIGINT NOT NULL,
    facility_id BIGINT NOT NULL,
    create_ts timestamptz null,
    update_ts timestamptz default now()
);
/
ALTER TABLE user_facility 
ADD CONSTRAINT unique_user_facility_id UNIQUE (user_id, facility_id);
/
DROP INDEX IF EXISTS idx_user_facility_user_id;
/
CREATE INDEX idx_user_facility_user_id ON user_facility(user_id);
/
DROP INDEX IF EXISTS idx_user_facility_update_ts;
/
CREATE INDEX idx_user_facility_update_ts ON user_facility(update_ts);
/
DROP INDEX IF EXISTS idx_user_facility_update_ts;
/
CREATE INDEX idx_user_facility_update_ts ON user_facility(create_ts);
/