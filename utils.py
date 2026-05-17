"""
TravelTide - Hilfsfunktionen
============================
Enthaelt:
  * haversine_distance: Grosskreis-Distanz zwischen zwei Punkten (km)
  * minmax_scale_series: Min-Max-Skalierung auf [0, 1]
  * iqr_outlier_mask: IQR-basierte Ausreisser-Maske
  * remove_outliers: filtert DataFrame anhand IQR
"""
from __future__ import annotations

import numpy as np
import pandas as pd


EARTH_RADIUS_KM = 6371.0


def haversine_distance(lat1, lon1, lat2, lon2) -> np.ndarray | float:
    """Distanz zwischen zwei Punkten in km (Annahme: perfekte Kugel).

    Akzeptiert Skalare oder pandas Series / numpy Arrays.
    """
    lat1 = np.radians(np.asarray(lat1, dtype=float))
    lon1 = np.radians(np.asarray(lon1, dtype=float))
    lat2 = np.radians(np.asarray(lat2, dtype=float))
    lon2 = np.radians(np.asarray(lon2, dtype=float))

    dlat = lat2 - lat1
    dlon = lon2 - lon1
    a = np.sin(dlat / 2.0) ** 2 + np.cos(lat1) * np.cos(lat2) * np.sin(dlon / 2.0) ** 2
    c = 2 * np.arcsin(np.sqrt(a))
    return EARTH_RADIUS_KM * c


def minmax_scale_series(s: pd.Series) -> pd.Series:
    """Skaliert eine Serie auf [0, 1]. Konstante Serien -> 0."""
    s = pd.to_numeric(s, errors="coerce")
    lo, hi = s.min(), s.max()
    if pd.isna(lo) or pd.isna(hi) or hi == lo:
        return pd.Series(np.zeros(len(s)), index=s.index)
    return (s - lo) / (hi - lo)


def iqr_outlier_mask(s: pd.Series, k: float = 1.5) -> pd.Series:
    """Boolesche Maske: True = Ausreisser nach IQR-Methode."""
    s = pd.to_numeric(s, errors="coerce")
    q1, q3 = s.quantile(0.25), s.quantile(0.75)
    iqr = q3 - q1
    lo, hi = q1 - k * iqr, q3 + k * iqr
    return (s < lo) | (s > hi)


def remove_outliers(df: pd.DataFrame, cols: list[str], k: float = 1.5) -> pd.DataFrame:
    """Entfernt Zeilen, die in mindestens einer der Spalten Ausreisser sind."""
    mask = pd.Series(False, index=df.index)
    for c in cols:
        if c in df.columns:
            mask |= iqr_outlier_mask(df[c], k=k)
    return df.loc[~mask].copy()
