# TravelTide – Customer Segmentation Projekt

Dieses Repository enthält das komplette Projekt für die Wochen 1–3 der TravelTide-Aufgabe (EDA, Datenvorverarbeitung, Feature Engineering).

## Inhalt

| Datei | Zweck |
|---|---|
| `traveltide_analysis.ipynb` | **Hauptnotebook** – kompletter Workflow in Python (Wochen 1–3) |
| `01_eda_queries.sql` | Reine SQL-Queries für die erste Datenexploration (Wochen 1) |
| `02_cohort_extraction.sql` | SQL für Kohorten-Filter + Session-Level-Extraktion |
| `03_user_level_aggregation.sql` | SQL für User-Level-Aggregation (alle Metriken in einem Query) |
| `utils.py` | Hilfsfunktionen (Haversine, MinMax, IQR-Outlier) |
| `requirements.txt` | Python-Abhängigkeiten |
| `REPORT.md` | Kurzer Ergebnis-Report |

## Verbindung

```python
DB_URL = "postgresql+psycopg2://Test:bQNxVzJL4g6u@ep-noisy-flower-846766.us-east-2.aws.neon.tech/TravelTide?sslmode=require"
```

## Quick Start (Google Colab)

1. Repo auf GitHub anlegen (z. B. `traveltide-segmentation`), Dateien hochladen.
2. In Colab: **File → Open notebook → GitHub** → Repo wählen → `traveltide_analysis.ipynb`.
3. Ersten Code-Cell ausführen – die `!pip install`-Zeile auskommentieren, falls nötig.
4. Notebook durchlaufen lassen – am Ende werden `traveltide_user_features.csv` und `traveltide_user_features_scaled.csv` exportiert.

## Quick Start (lokal)

```bash
pip install -r requirements.txt
jupyter notebook traveltide_analysis.ipynb
```

## Kohorten-Definition

Wir nutzen Elenas Standard-Cohort:

- Sessions ab **2023-01-04**
- Nur User mit **> 7 Sessions** in diesem Zeitraum

Erwartet: ~49.211 Zeilen auf Session-Level, ~5.998 eindeutige User.

## Pipeline (kurz)

```
sessions ─┐
flights  ─┼── JOIN ──► Session-Level-Datensatz
hotels   ─┤              │
users    ─┘              ▼
                      Cleaning (nights, NULLs)
                         │
                         ▼
                  Haversine, ADS, Session-Dauer
                         │
                         ▼
                User-Level-Aggregation (GROUP BY user_id)
                         │
                         ▼
                Index-Metriken (bargain_hunter, …)
                         │
                         ▼
                  IQR-Outlier-Removal (k=3)
                         │
                         ▼
                    MinMax-Skalierung
                         │
                         ▼
                   CSV-Export → Woche 4 (Clustering)
```

## Metriken-Übersicht

| Kategorie | Spalten (User-Level) |
|---|---|
| Demografie | `age`, `gender`, `married`, `has_children`, `home_*`, `months_since_signup` |
| Engagement | `num_sessions`, `avg_page_clicks`, `avg_session_duration_sec`, `cancellation_rate` |
| Flight | `num_flight_bookings`, `avg_flight_discount`, `avg_base_fare_usd`, `total_flight_spend_usd`, `avg_flight_distance_km`, `ads_per_km`, `num_return_flights` |
| Hotel | `num_hotel_bookings`, `avg_hotel_discount`, `avg_hotel_price_per_room`, `avg_nights_per_stay`, `total_hotel_spend_usd`, `avg_rooms` |
| Discount-Affinität | `discount_flight_proportion`, `discount_hotel_proportion` |
| Indizes (Personas) | `bargain_hunter_index`, `family_traveler_index`, `business_traveler_index`, `luxury_index`, `loyalty_index` |

## GitHub-Workflow

Nach jedem Meilenstein: `File → Save a copy in GitHub` aus Colab heraus. Das pusht einen Commit, ohne dass du Git-Kommandos eingeben musst.

## Nächste Schritte (Woche 4+)

- Clustering (KMeans, evtl. mit Elbow-Methode) auf den **`_scaled`-Spalten**
- Persona-Labels pro Cluster vergeben
- Perk-Empfehlung pro Cluster definieren
- Ergebnis-Dashboard / Slides für Elena vorbereiten
