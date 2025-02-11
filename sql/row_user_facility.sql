INSERT INTO daas.user_facility (user_id, fac_id, create_ts)
SELECT au.id, f.id, now() 
FROM daas.auth_user au 
FULL OUTER JOIN daas.facility f ON 1=1 
WHERE au.username = 'daas'
AND NOT EXISTS 
	(SELECT 1 FROM daas.user_facility uf2
	JOIN daas.auth_user au2 ON uf2.user_id = au2.id
	AND uf2.fac_id = f.id AND au2.id = au.id)