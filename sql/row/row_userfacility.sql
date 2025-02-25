
DO '
BEGIN
	IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = ''auth_user'') THEN

		INSERT INTO userfacility (user_id, facility_id, create_ts)
		SELECT au.id, f.id, now() 
		FROM auth_user au 
		FULL OUTER JOIN facility f ON 1=1 
		WHERE 
			au.username = ''daas''
			AND NOT EXISTS 
				(SELECT 1 FROM userfacility uf2
				JOIN auth_user au2 ON uf2.user_id = au2.id
				AND uf2.facility_id = f.id AND au2.id = au.id);

	END IF;

END ' LANGUAGE plpgsql;
/