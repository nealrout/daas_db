CALL drop_functions_by_name('get_event_notification_buffer');
/
-- Stored procedure to get all items
CREATE OR REPLACE FUNCTION get_event_notification_buffer(p_channel_name TEXT)
RETURNS TABLE(id BIGINT, channel TEXT, payload TEXT, create_ts timestamptz) AS '
BEGIN
    RETURN QUERY
    SELECT 
		b.id, b.channel, b.payload, b.create_ts
	FROM 
		event_notification_buffer b
	WHERE
		b.channel = p_channel_name
	ORDER BY
		b.create_ts ASC;

END;
' LANGUAGE plpgsql;
/
CALL drop_functions_by_name('clean_event_notification_buffer');
/
-- Stored procedure to get all items
CREATE OR REPLACE FUNCTION clean_event_notification_buffer(p_jsonb jsonb, p_channel text)
RETURNS VOID AS '
BEGIN
	DELETE FROM event_notification_buffer b
	WHERE EXISTS (SELECT 1 FROM 
		(
				SELECT b.id, b.channel, b.payload
				FROM event_notification_buffer b_in
				JOIN get_jsonb_values_by_key (p_jsonb, ''domain_nbr'') j 
					ON b_in.payload = j.value and b_in.channel = p_channel

		) AS q
		WHERE b.channel = q.channel AND b.payload = q.payload);
END;
' LANGUAGE plpgsql;
/
