CALL drop_procedures_by_name('daas_log');
/
CREATE OR REPLACE PROCEDURE daas_log(p_level TEXT, p_message TEXT, p_file_name TEXT, p_line_number bigint)
AS '
DECLARE
BEGIN
    INSERT INTO log (level, message, file_name, line_number, create_ts)
	VALUES (p_level, p_message, p_file_name, p_line_number, now());
END; 
' LANGUAGE plpgsql;
/

