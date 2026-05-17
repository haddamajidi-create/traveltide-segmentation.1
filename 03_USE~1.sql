-- =====================================================================
-- TravelTide - Woche 2 (Feature Engineering / User-Level-Aggregation)
-- =====================================================================
-- Wir aggregieren die Session-Level-Daten auf User-Ebene.
-- Pro user_id berechnen wir verhaltensbezogene Metriken, die später
-- für die Segmentierung verwendet werden.
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
),
session_base AS (
    SELECT
        s.*,
        EXTRACT(EPOCH FROM (s.session_end - s.session_start)) AS session_duration_sec,
        -- gültige Buchung = booked AND NOT canceled
        (s.flight_booked AND NOT s.cancellation) AS valid_flight_booking,
        (s.hotel_booked  AND NOT s.cancellation) AS valid_hotel_booking
    FROM sessions_2023 s
    JOIN cohort_users cu ON s.user_id = cu.user_id
),
session_with_trip AS (
    SELECT
        sb.*,
        u.birthdate,
        u.gender,
        u.married,
        u.has_children,
        u.home_country,
        u.home_city,
        u.home_airport,
        u.home_airport_lat,
        u.home_airport_lon,
        u.sign_up_date,

        f.base_fare_usd,
        f.seats,
        f.checked_bags,
        f.return_flight_booked,
        f.trip_airline,
        f.destination_airport_lat,
        f.destination_airport_lon,
        f.departure_time,
        f.return_time,

        -- Haversine-Distanz vom Heimat- zum Zielflughafen in km
        CASE
          WHEN sb.valid_flight_booking AND f.destination_airport_lat IS NOT NULL THEN
            2 * 6371 * ASIN( SQRT(
                POWER( SIN(RADIANS((f.destination_airport_lat - u.home_airport_lat)/2)), 2 )
              + COS(RADIANS(u.home_airport_lat)) * COS(RADIANS(f.destination_airport_lat))
                * POWER( SIN(RADIANS((f.destination_airport_lon - u.home_airport_lon)/2)), 2 )
            ))
          ELSE NULL
        END AS flight_distance_km,

        -- Gesparte Dollar pro Flug
        CASE
          WHEN sb.valid_flight_booking
          THEN f.base_fare_usd * COALESCE(sb.flight_discount_amount, 0)
          ELSE NULL
        END AS dollars_saved_flight,

        h.hotel_name,
        -- Nights bereinigen: negative/0-Werte aus check_in/check_out rekonstruieren
        CASE
          WHEN h.nights IS NULL THEN NULL
          WHEN h.nights <= 0 AND h.check_in_time IS NOT NULL AND h.check_out_time IS NOT NULL
            THEN GREATEST(1, DATE_PART('day', h.check_out_time - h.check_in_time)::int)
          WHEN h.nights <= 0 THEN 1            -- Fallback
          ELSE h.nights
        END AS nights_clean,
        h.rooms,
        h.hotel_per_room_usd,
        h.check_in_time,
        h.check_out_time

    FROM session_base sb
    LEFT JOIN users    u ON sb.user_id = u.user_id
    LEFT JOIN flights  f ON sb.trip_id = f.trip_id
    LEFT JOIN hotels   h ON sb.trip_id = h.trip_id
)

SELECT
    user_id,

    -- ===== Demografie (ein Wert pro User) =====
    MIN(birthdate)        AS birthdate,
    MIN(DATE_PART('year', AGE(CURRENT_DATE, birthdate))) AS age,
    MIN(gender)           AS gender,
    BOOL_OR(married)      AS married,
    BOOL_OR(has_children) AS has_children,
    MIN(home_country)     AS home_country,
    MIN(home_city)        AS home_city,
    MIN(home_airport)     AS home_airport,
    MIN(sign_up_date)     AS sign_up_date,
    DATE_PART('year',  AGE(CURRENT_DATE, MIN(sign_up_date))) * 12
      + DATE_PART('month', AGE(CURRENT_DATE, MIN(sign_up_date))) AS months_since_signup,

    -- ===== Engagement / Browsing =====
    COUNT(*)                                                 AS num_sessions,
    AVG(session_duration_sec)                                AS avg_session_duration_sec,
    AVG(page_clicks)                                         AS avg_page_clicks,
    SUM(page_clicks)                                         AS total_page_clicks,
    SUM(CASE WHEN cancellation THEN 1 ELSE 0 END)            AS num_cancellations,
    SUM(CASE WHEN cancellation THEN 1 ELSE 0 END)::float /
      NULLIF(COUNT(*), 0)                                    AS cancellation_rate,

    -- ===== Flight-Verhalten =====
    SUM(CASE WHEN valid_flight_booking THEN 1 ELSE 0 END)    AS num_flight_bookings,
    SUM(CASE WHEN valid_flight_booking AND flight_discount THEN 1 ELSE 0 END)
      AS num_discounted_flight_bookings,
    AVG(CASE WHEN valid_flight_booking THEN flight_discount_amount END)
      AS avg_flight_discount,
    AVG(CASE WHEN valid_flight_booking THEN base_fare_usd END)
      AS avg_base_fare_usd,
    SUM(CASE WHEN valid_flight_booking THEN base_fare_usd ELSE 0 END)
      AS total_flight_spend_usd,
    SUM(CASE WHEN valid_flight_booking THEN dollars_saved_flight ELSE 0 END)
      AS total_dollars_saved_flight,
    AVG(flight_distance_km)
      AS avg_flight_distance_km,
    SUM(flight_distance_km)
      AS total_flight_distance_km,
    AVG(CASE WHEN valid_flight_booking THEN seats END)         AS avg_seats,
    AVG(CASE WHEN valid_flight_booking THEN checked_bags END)  AS avg_checked_bags,
    SUM(CASE WHEN valid_flight_booking AND return_flight_booked THEN 1 ELSE 0 END)
      AS num_return_flights,

    -- ===== Hotel-Verhalten =====
    SUM(CASE WHEN valid_hotel_booking THEN 1 ELSE 0 END)     AS num_hotel_bookings,
    SUM(CASE WHEN valid_hotel_booking AND hotel_discount THEN 1 ELSE 0 END)
      AS num_discounted_hotel_bookings,
    AVG(CASE WHEN valid_hotel_booking THEN hotel_discount_amount END)
      AS avg_hotel_discount,
    AVG(CASE WHEN valid_hotel_booking THEN hotel_per_room_usd END)
      AS avg_hotel_price_per_room,
    AVG(CASE WHEN valid_hotel_booking THEN nights_clean END)
      AS avg_nights_per_stay,
    SUM(CASE WHEN valid_hotel_booking THEN nights_clean * rooms * hotel_per_room_usd ELSE 0 END)
      AS total_hotel_spend_usd,
    AVG(CASE WHEN valid_hotel_booking THEN rooms END)
      AS avg_rooms,

    -- ===== Discount-Affinität (Anteile) =====
    CASE WHEN SUM(CASE WHEN valid_flight_booking THEN 1 ELSE 0 END) > 0
         THEN SUM(CASE WHEN valid_flight_booking AND flight_discount THEN 1 ELSE 0 END)::float
              / SUM(CASE WHEN valid_flight_booking THEN 1 ELSE 0 END)
         ELSE 0
    END AS discount_flight_proportion,

    CASE WHEN SUM(CASE WHEN valid_hotel_booking THEN 1 ELSE 0 END) > 0
         THEN SUM(CASE WHEN valid_hotel_booking AND hotel_discount THEN 1 ELSE 0 END)::float
              / SUM(CASE WHEN valid_hotel_booking THEN 1 ELSE 0 END)
         ELSE 0
    END AS discount_hotel_proportion,

    -- ===== ADS pro km (Average Dollars Saved per Kilometer) =====
    CASE WHEN SUM(flight_distance_km) > 0
         THEN SUM(CASE WHEN valid_flight_booking THEN dollars_saved_flight ELSE 0 END)
              / SUM(flight_distance_km)
         ELSE 0
    END AS ads_per_km

FROM session_with_trip
GROUP BY user_id
;
