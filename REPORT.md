# TravelTide – Projekt-Report (Wochen 1–3)

## Schema – Fact vs. Dimension

`sessions` ist die zentrale **Fact-Tabelle**: sie hat das feinste Granularitäts­niveau (eine Zeile pro Browsing-Session) und wird kontinuierlich nachgeführt. `users` ist eine klassische **Dimensionstabelle** – sie liefert statische, beschreibende Attribute zu jedem User und ist über `user_id` mit `sessions` verbunden. `flights` und `hotels` sind ebenfalls Fact-Tabellen (Transaction Facts), die über `trip_id` an die jeweilige Session geknüpft sind und für jede Buchung eine eigene Zeile enthalten.

## Woche 1 – EDA

- Tabellengrößen wurden mit `SELECT COUNT(*)` pro Tabelle ermittelt.
- Null-Checks und Duplikat-Prüfungen wurden in SQL durchgeführt (siehe `01_eda_queries.sql`).
- Im Feld `hotel_name` ist die Zielstadt oft mit eingebettet – das lässt sich später nutzen, um „Heimat-Buchungen" zu erkennen.
- Geburtsjahr 2006 zeigt einen auffälligen Peak, was sehr wahrscheinlich auf einen Default-Wert beim Registrierungs­formular zurück­geht. Daraus berechnetes Alter sollte mit Vorsicht interpretiert werden.
- Alternative zur Altersdefinition: `months_since_signup = DATE_PART('month', AGE(NOW(), sign_up_date)) + DATE_PART('year', …)*12`.
- Anomalien in `nights` (0 oder negativ) wurden anhand `check_out_time - check_in_time` rekonstruiert.

## Woche 2 – Metriken

Pro User wurden Metriken aus fünf Kategorien gebildet:

- **Basis-Counts:** `num_sessions`, `num_flight_bookings`, `num_hotel_bookings`, `num_cancellations`.
- **Zentrale Tendenz:** `avg_flight_discount`, `avg_hotel_discount`, `avg_base_fare_usd`, `avg_hotel_price_per_room`, `avg_nights_per_stay`.
- **Raten/Verhältnisse:** `discount_flight_proportion`, `discount_hotel_proportion`, `cancellation_rate`.
- **Distanz-normierte Rate:** `ads_per_km = total_dollars_saved / total_distance_km` – behebt den Bias, dass Langstreckenflieger automatisch mehr gespart hätten.
- **Indizes (Personas):** `bargain_hunter_index`, `family_traveler_index`, `business_traveler_index`, `luxury_index`, `loyalty_index` – jeweils Produkte korrelations­armer Einzelmetriken, einfach erklärbar.

Die Haversine-Distanz wird über `home_airport_lat/lon` und `destination_airport_lat/lon` berechnet (in `utils.py` als `haversine_distance`).

## Woche 3 – Datenvorverarbeitung

1. **Kohorte:** Sessions ab `2023-01-04`, User mit mehr als 7 Sessions → ~49.211 Zeilen auf Session-Level (entspricht Elenas erwartetem Wert).
2. **Cleaning:** Anomalien in `nights` aus `check_out - check_in` rekonstruiert; Fallback = 1.
3. **Aggregation:** `GROUP BY user_id` mit allen Metriken.
4. **Ausreißer:** IQR × 3 – sehr konservativ, entfernt nur eindeutige Extreme.
5. **Skalierung:** MinMax auf [0, 1] für alle Metriken, damit kein Feature wegen seiner Einheit die Distanz­berechnung dominiert.
6. **Export:** `traveltide_user_features.csv` und `traveltide_user_features_scaled.csv`.

## Wichtige Entscheidungen

- **Stornierte Buchungen werden nicht gewertet** (`valid_flight = booked AND NOT cancellation`) – stornierte Buchungen sind kein Ausdruck eines tatsächlich genutzten Perks.
- **Index-Multiplikation statt Summe:** Produkte heben Verhaltens­profile hervor, bei denen mehrere Eigenschaften gleichzeitig zutreffen. Korrelations­arme Metriken wurden bewusst kombiniert.
- **MinMax statt Z-Score:** MinMax erhält die relativen Abstände und ist für Marketing-Stakeholder leichter zu kommunizieren („0 = niedrigste, 1 = höchste Affinität").
- **Geburtsjahr 2006:** wir lassen die Werte stehen, dokumentieren aber, dass das berechnete Alter für diese User unverlässlich ist.

## Ausblick (Woche 4)

- KMeans-Clustering auf den `_scaled`-Spalten, Elbow-Methode für `k`.
- Cluster-Profilbeschreibung, Persona-Label.
- Perk-Mapping pro Cluster:
  - High `bargain_hunter_index` → exklusive Rabatte
  - High `family_traveler_index` → free Checked Bag / Kid-Friendly Perks
  - High `business_traveler_index` → Priority Boarding
  - High `luxury_index` → Hotel-Upgrades
  - High `loyalty_index` → Status-Punkte
