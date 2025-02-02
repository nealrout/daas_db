

CREATE OR REPLACE PROCEDURE drop_functions_by_name(proc_name VARCHAR)
LANGUAGE plpgsql AS '
DECLARE
    func RECORD;
BEGIN
    FOR func IN
        SELECT proname, oidvectortypes(proargtypes) AS args
        FROM pg_proc
        WHERE proname = proc_name
    LOOP
        EXECUTE ''DROP FUNCTION '' || func.proname || ''('' || func.args || '')'';
    END LOOP;
END ';


CREATE OR REPLACE PROCEDURE drop_procedures_by_name(proc_name VARCHAR)
LANGUAGE plpgsql AS '
DECLARE
    proc RECORD;
BEGIN
    FOR proc IN
        SELECT proname, oidvectortypes(proargtypes) AS args
        FROM pg_proc
        WHERE proname = proc_name AND prokind = ''p''
    LOOP
        EXECUTE ''DROP PROCEDURE '' || proc.proname || ''('' || proc.args || '')'';
    END LOOP;
END ';
