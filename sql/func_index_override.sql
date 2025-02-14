CALL drop_functions_by_name('get_index_override');
/
CREATE OR REPLACE FUNCTION get_index_override(p_domain TEXT)
RETURNS TABLE(id bigint, domain text, index_source_ts timestamptz, index_target_ts timestamptz) AS ' 
DECLARE
BEGIN
    RETURN QUERY
    SELECT i.id, i.domain, i.index_source_ts, i.index_target_ts
    from index_override i
    WHERE i.domain = p_domain;
END;
' LANGUAGE plpgsql;
/
CALL drop_functions_by_name('clean_index_override');
/
CREATE OR REPLACE FUNCTION clean_index_override(p_domain TEXT)
RETURNS VOID AS ' 
DECLARE
BEGIN
    DELETE
    from index_override
    WHERE domain = p_domain;
END;
' LANGUAGE plpgsql;
/
