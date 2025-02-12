

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
CALL drop_functions_by_name('iterate_json_keys');
/
CREATE OR REPLACE FUNCTION iterate_json_keys(json_input jsonb)
RETURNS TABLE (json_output jsonb) AS
'
DECLARE
    key_text TEXT;
    value_json jsonb;
BEGIN
    -- Iterate over each key in the JSON object
    FOR key_text, value_json IN 
        SELECT key, json_input->key 
        FROM jsonb_each(json_input)  -- Extracts each key-value pair
    LOOP
        -- Return each key and its corresponding array as a separate JSON object
        json_output := jsonb_build_object(key_text, value_json);
        RETURN NEXT;
    END LOOP;
END;
' LANGUAGE plpgsql;
/