CALL drop_functions_by_name('get_index_override');
/
CREATE OR REPLACE FUNCTION get_index_override(p_domain TEXT)
RETURNS TABLE(id bigint, domain text, index_source_ts timestamptz, index_target_ts timestamptz) AS ' 
DECLARE
BEGIN
    RETURN QUERY
    SELECT i.id, i.domain, i.index_source_ts, i.index_target_ts
    from index_override i
    WHERE UPPER(i.domain) = UPPER(p_domain);
END;
' LANGUAGE plpgsql;
/
CALL drop_procedures_by_name('clean_index_override');
/
CREATE OR REPLACE PROCEDURE clean_index_override(p_domain TEXT)
AS '
DECLARE
BEGIN
    INSERT INTO index_override_history (domain, index_source_ts, index_target_ts)
    SELECT i.domain, i.index_source_ts, i.index_target_ts
    FROM index_override i
    WHERE UPPER(i.domain) = UPPER(p_domain);

    DELETE
    from index_override i
    WHERE UPPER(i.domain) = UPPER(p_domain);
END; 
' LANGUAGE plpgsql;
/

