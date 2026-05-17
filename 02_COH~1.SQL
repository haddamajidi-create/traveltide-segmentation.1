-- =====================================================================
-- TravelTide - Woche 3 (Datenvorverarbeitung)
-- Kohorte filtern + Session-Level-Extraktion
-- =====================================================================
-- Elenas Kohorte:
--   * Sessions ab 04.01.2023
--   * Nur User mit > 7 Sessions in diesem Zeitraum
-- Erwartetes Ergebnis: ~49.211 Zeilen auf Session-Level
-- =====================================================================

WITH sessions_2023 AS (
    SELECT *
    FROM sessions
    WHERE session_start >= '2023-01-04'
),
cohort_users AS (
    SELECT user_id
    FROM sessions_2023
    GROUP BY user_id
    HAVING COUNT(*) > 7
)
SELECT
    s.session_id,
    s.user_id,
    s.trip_id,
    s.session_start,
    s.session_end,
    EXTRACT(EPOCH FROM (s.session_end - s.session_start)) AS session_duration_sec,
    s.page_clicks,
    s.flight_discount,
    s.hotel_discount,
    s.flight_discount_amount,
    s.hotel_discount_amount,
    s.flight_booked,
    s.hotel_booked,
    s.cancellation,

    -- User-Demografie
    u.birthdate,
    DATE_PART('year', AGE(CURRENT_DATE, u.birthdate)) AS age,
    u.gender,
    u.married,
    u.has_children,
    u.home_country,
    u.home_city,
    u.home_airport,
    u.home_airport_lat,
    u.home_airport_lon,
    u.sign_up_date,

    -- Flight-Infos (nur wenn flight_booked = TRUE und nicht storniert)
    f.origin_airport,
    f.destination,
    f.destination_airport,
    f.destination_airport_lat,
    f.destination_airport_lon,
    f.seats,
    f.return_flight_booked,
    f.departure_time,
    f.return_time,
    f.checked_bags,
    f.trip_airline,
    f.base_fare_usd,

    -- Hotel-Infos (nur wenn hotel_booked = TRUE und nicht storniert)
    h.hotel_name,
    h.nights,
    h.rooms,
    h.check_in_time,
    h.check_out_time,
    h.hotel_per_room_usd,

    -- Haversine-Distanz vom Heimatflughafen zum Ziel (falls Flug gebucht)
    -- Formel direkt im Query, weil custom UDF haversine_distance evtl. fehlt
    CASE
      WHEN f.destination_airport_lat IS NOT NULL THEN
        2 * 6371 * ASIN( SQRT(
            POWER( SIN(RADIANS((f.destination_airport_lat - u.home_airport_lat)/2)), 2 )
          + COS(RADIANS(u.home_airport_lat)) * COS(RADIANS(f.destination_airport_lat))
            * POWER( SIN(RADIANS((f.destination_airport_lon - u.home_airport_lon)/2)), 2 )
        ))
      ELSE NULL
    END AS haversine_distance_km

FROM sessions_2023 s
JOIN cohort_users cu ON s.user_id = cu.user_id
LEFT JOIN users    u ON s.user_id = u.user_id
LEFT JOIN flights  f ON s.trip_id = f.trip_id
LEFT JOIN hotels   h ON s.trip_id = h.trip_id
;
