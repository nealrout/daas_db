
CALL drop_functions_by_name('get_index_log');
/
CREATE OR REPLACE FUNCTION get_index_log(p_domain TEXT, p_status_code CITEXT)
RETURNS TABLE(id bigint, domain text, status_code CITEXT, description TEXT) AS ' 
DECLARE
BEGIN
    p_status_code = UPPER(p_status_code);

    RETURN QUERY
    select i.id, i.domain, i.status_code, i.description
    from index_log i
    where i.domain = p_domain
    and i.status_code = p_status_code
    order by create_ts desc
    limit 1;
END;
' LANGUAGE plpgsql;
/
CALL drop_functions_by_name('upsert_index_log');
/
CREATE OR REPLACE FUNCTION upsert_index_log(p_id bigint, p_domain TEXT, p_status_code CITEXT, p_description TEXT)
RETURNS TABLE(id bigint, domain text, status_code CITEXT, description TEXT) AS ' 
DECLARE
BEGIN

    p_status_code = UPPER(p_status_code);
    IF (SELECT count(*) FROM index_status s WHERE s.status_code = p_status_code) = 0 THEN
        p_status_code = ''UNKNOWN'';
    END IF;

	-- Perform UPSERT: Insert new records or update existing ones
	MERGE INTO index_log AS target
	USING (SELECT coalesce(p_id,-1) as id) AS source
	ON target.id = source.id
	WHEN MATCHED THEN
	    UPDATE SET 
	        status_code  = p_status_code,
            description = p_description,
	        update_ts = now()
	WHEN NOT MATCHED THEN
	    INSERT (domain, status_code, description, create_ts)
	    VALUES (p_domain, p_status_code, p_description, now());

    RETURN QUERY
    select i.id, i.domain, i.status_code, i.description
    from index_log i
    where i.id = p_id;
	
END;
' LANGUAGE plpgsql;
/
