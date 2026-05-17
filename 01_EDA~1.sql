-- =====================================================================
-- TravelTide - Woche 1: Erste Datenexploration (EDA)
-- =====================================================================
-- Diese SQL-Datei enthält alle Queries, um die TravelTide-DB zu erkunden.
-- Verbindung: postgres://Test:bQNxVzJL4g6u@ep-noisy-flower-846766.us-east-2.aws.neon.tech/TravelTide?sslmode=require
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. Datenstruktur verstehen - Zeilenanzahl pro Tabelle
-- ---------------------------------------------------------------------
SELECT 'users'    AS table_name, COUNT(*) AS row_count FROM users
UNION ALL
SELECT 'sessions' AS table_name, COUNT(*) AS row_count FROM sessions
UNION ALL
SELECT 'flights'  AS table_name, COUNT(*) AS row_count FROM flights
UNION ALL
SELECT 'hotels'   AS table_name, COUNT(*) AS row_count FROM hotels;


-- ---------------------------------------------------------------------
-- 2. Datentypen aller Spalten
-- ---------------------------------------------------------------------
SELECT table_name, column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name IN ('users','sessions','flights','hotels')
ORDER BY table_name, ordinal_position;


-- ---------------------------------------------------------------------
-- 3. Datenqualität - Null-Werte pro Spalte (Beispiel sessions)
-- ---------------------------------------------------------------------
SELECT
  COUNT(*) FILTER (WHERE session_id IS NULL)               AS null_session_id,
  COUNT(*) FILTER (WHERE user_id IS NULL)                  AS null_user_id,
  COUNT(*) FILTER (WHERE trip_id IS NULL)                  AS null_trip_id,
  COUNT(*) FILTER (WHERE flight_discount_amount IS NULL)   AS null_flight_disc_amount,
  COUNT(*) FILTER (WHERE hotel_discount_amount IS NULL)    AS null_hotel_disc_amount
FROM sessions;


-- ---------------------------------------------------------------------
-- 4. hotel_name - gibt es ein einheitliches Format?
--    Hier zeigt sich, dass im hotel_name oft die Stadt mitkodiert ist.
-- ---------------------------------------------------------------------
SELECT hotel_name, COUNT(*) AS occurrences
FROM hotels
GROUP BY hotel_name
ORDER BY occurrences DESC
LIMIT 30;


-- ---------------------------------------------------------------------
-- 5. Demografie - Verteilung nach Geschlecht, Familienstand, Eltern
-- ---------------------------------------------------------------------
SELECT gender, married, has_children, COUNT(*) AS n
FROM users
GROUP BY gender, married, has_children
ORDER BY n DESC;


-- ---------------------------------------------------------------------
-- 6. Geburtsjahre - Was ist mit 2006 los?
-- ---------------------------------------------------------------------
SELECT EXTRACT(YEAR FROM birthdate) AS birth_year, COUNT(*) AS n
FROM users
GROUP BY birth_year
ORDER BY birth_year;


-- ---------------------------------------------------------------------
-- 7. Alter aus birthdate berechnen
-- ---------------------------------------------------------------------
SELECT
  AVG( DATE_PART('year', AGE(CURRENT_DATE, birthdate)) ) AS avg_age,
  MIN( DATE_PART('year', AGE(CURRENT_DATE, birthdate)) ) AS min_age,
  MAX( DATE_PART('year', AGE(CURRENT_DATE, birthdate)) ) AS max_age
FROM users
WHERE birthdate IS NOT NULL;


-- ---------------------------------------------------------------------
-- 8. "Kund:innenalter" = Monate seit sign_up
-- ---------------------------------------------------------------------
SELECT
  AVG( DATE_PART('year', AGE(CURRENT_DATE, sign_up_date))*12
     + DATE_PART('month', AGE(CURRENT_DATE, sign_up_date)) ) AS avg_months_since_signup
FROM users;


-- ---------------------------------------------------------------------
-- 9. Top 10 beliebteste Hotels (mit Aufenthaltsdauer & Preis)
-- ---------------------------------------------------------------------
SELECT
  hotel_name,
  COUNT(*)                              AS bookings,
  ROUND(AVG(nights)::numeric, 2)        AS avg_nights,
  ROUND(AVG(hotel_per_room_usd)::numeric, 2) AS avg_price_per_room
FROM hotels
WHERE nights > 0                       -- Anomalien rausfiltern (siehe unten)
GROUP BY hotel_name
ORDER BY bookings DESC
LIMIT 10;


-- ---------------------------------------------------------------------
-- 10. Top 10 teuerste Hotels
-- ---------------------------------------------------------------------
SELECT
  hotel_name,
  ROUND(AVG(hotel_per_room_usd)::numeric, 2) AS avg_price_per_room,
  COUNT(*) AS bookings
FROM hotels
GROUP BY hotel_name
ORDER BY avg_price_per_room DESC
LIMIT 10;


-- ---------------------------------------------------------------------
-- 11. Top 10 Hotels mit längsten Aufenthalten
-- ---------------------------------------------------------------------
SELECT
  hotel_name,
  ROUND(AVG(nights)::numeric, 2) AS avg_nights,
  COUNT(*) AS bookings
FROM hotels
WHERE nights > 0
GROUP BY hotel_name
ORDER BY avg_nights DESC
LIMIT 10;


-- ---------------------------------------------------------------------
-- 12. Anomalien in nights - negative oder Null-Übernachtungen?
-- ---------------------------------------------------------------------
SELECT nights, COUNT(*) AS n
FROM hotels
GROUP BY nights
ORDER BY nights
LIMIT 20;

-- Vergleich: rekonstruierte Nights aus check_in/check_out
SELECT
  trip_id,
  nights AS nights_in_data,
  DATE_PART('day', check_out_time - check_in_time) AS nights_reconstructed
FROM hotels
WHERE nights <= 0
LIMIT 20;


-- ---------------------------------------------------------------------
-- 13. Flight-Tabelle - meistgenutzte Fluggesellschaft letzte 6 Monate
-- ---------------------------------------------------------------------
SELECT trip_airline, COUNT(*) AS flights
FROM flights
WHERE departure_time >= CURRENT_DATE - INTERVAL '6 months'
GROUP BY trip_airline
ORDER BY flights DESC
LIMIT 10;


-- ---------------------------------------------------------------------
-- 14. Durchschnittliche Sitzplatzanzahl pro Buchung
-- ---------------------------------------------------------------------
SELECT ROUND(AVG(seats)::numeric, 2) AS avg_seats
FROM flights;


-- ---------------------------------------------------------------------
-- 15. Preisschwankung dieselbe Route nach Saison (Quartal)
-- ---------------------------------------------------------------------
SELECT
  origin_airport,
  destination_airport,
  EXTRACT(QUARTER FROM departure_time) AS quarter,
  ROUND(AVG(base_fare_usd)::numeric, 2) AS avg_fare,
  COUNT(*) AS n
FROM flights
GROUP BY origin_airport, destination_airport, quarter
HAVING COUNT(*) > 50
ORDER BY origin_airport, destination_airport, quarter;


-- ---------------------------------------------------------------------
-- 16. Durchschnittliche Page Clicks pro Session
-- ---------------------------------------------------------------------
SELECT
  ROUND(AVG(page_clicks)::numeric, 2)               AS avg_clicks,
  PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY page_clicks) AS median_clicks,
  MAX(page_clicks)                                  AS max_clicks
FROM sessions;
