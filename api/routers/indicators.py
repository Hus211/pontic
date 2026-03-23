# Pontic — Indicators Router

from fastapi import APIRouter, Query
from api.services.db import query_all, query_one
from api.services.cache import get_cached, set_cached
from api.config import get_settings

router   = APIRouter(prefix="/indicators", tags=["Indicators"])
settings = get_settings()


@router.get("/")
def list_indicators(
    source:  str | None = Query(None, description="Filter by source e.g. FRED"),
    country: str | None = Query(None, description="Filter by country code e.g. US"),
):
    """List all macro indicators with latest values and signals."""
    cache_key = f"indicators:{source}:{country}"
    cached = get_cached(cache_key)
    if cached:
        return cached

    where = "WHERE 1=1"
    params = {}
    if source:
        where  += " AND source = :source"
        params["source"] = source.upper()
    if country:
        where  += " AND country_code = :country"
        params["country"] = country.upper()

    rows = query_all(f"""
        SELECT
            source, series_key, indicator_name, unit, frequency,
            country_code, latest_date, latest_value,
            mom_pct, yoy_pct, zscore, mom_direction, zscore_label,
            fetched_at
        FROM public_marts.mart_macro_signals
        {where}
        ORDER BY ABS(COALESCE(zscore, 0)) DESC
    """, params)

    result = {"count": len(rows), "indicators": rows}
    set_cached(cache_key, result)
    return result


@router.get("/{series_key}")
def get_indicator(
    series_key: str,
    country:    str = Query("US"),
    limit:      int = Query(120, ge=1, le=500),
):
    """Get full time series for a specific indicator."""
    cache_key = f"indicator:{series_key}:{country}:{limit}"
    cached = get_cached(cache_key)
    if cached:
        return cached

    rows = query_all("""
        SELECT
            source, series_key, indicator_name, unit, frequency,
            country_code, date, value, mom_pct, yoy_pct, zscore,
            mom_direction, zscore_label, fetched_at
        FROM public_intermediate.int_indicators_zscore
        WHERE series_key    = :series_key
          AND country_code  = :country
          AND value IS NOT NULL
        ORDER BY date DESC
        LIMIT :limit
    """, {"series_key": series_key.upper(), "country": country.upper(), "limit": limit})

    if not rows:
        from fastapi import HTTPException
        raise HTTPException(status_code=404, detail=f"Indicator '{series_key}' not found")

    result = {
        "series_key":     series_key.upper(),
        "indicator_name": rows[0]["indicator_name"],
        "unit":           rows[0]["unit"],
        "country_code":   country.upper(),
        "count":          len(rows),
        "data":           rows,
    }
    set_cached(cache_key, result)
    return result
