

CALL drop_functions_by_name('get_jsonb_values_by_key');
/
-- Stored procedure to get all items
CREATE OR REPLACE FUNCTION get_jsonb_values_by_key(p_jsonb jsonb, p_key text)
RETURNS TABLE(value text) AS '
BEGIN
	-- Check if p_jsonb is NULL or an empty array
    IF p_jsonb IS NULL OR p_jsonb = ''[]''::jsonb OR jsonb_typeof(p_jsonb) IS NULL THEN
        RETURN;  -- Exit function without returning any rows
    END IF;

    -- Ensure p_jsonb contains an object and the key exists
    IF jsonb_typeof(p_jsonb) <> ''object'' OR NOT p_jsonb ? p_key THEN
        RETURN;
    END IF;

    -- Extract JSON values safely
    RETURN QUERY 
    SELECT array_value
	FROM jsonb_each_text(p_jsonb) AS elem
	JOIN LATERAL jsonb_array_elements_text(elem.value::jsonb) AS array_value ON elem.key = p_key
    WHERE key = p_key;
END;
' LANGUAGE plpgsql;
/
