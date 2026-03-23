# Pontic — Market Signals Router

from fastapi import APIRouter, Query
from api.services.db import query_all
from api.services.cache import get_cached, set_cached

router = APIRouter(prefix="/signals", tags=["Signals"])


@router.get("/market")
def market_signals(category: str | None = Query(None)):
    """Get latest market proxy signals with momentum."""
    cache_key = f"signals:market:{category}"
    cached = get_cached(cache_key)
    if cached:
        return cached

    where  = "WHERE 1=1"
    params = {}
    if category:
        where  += " AND category = :category"
        params["category"] = category.lower()

    rows = query_all(f"""
        SELECT
            series_key, ticker, asset_name, category, unit,
            latest_date, latest_price, sma_20, sma_50,
            return_1m_pct, return_3m_pct, above_sma20, trend_signal
        FROM public_marts.mart_market_snapshot
        {where}
        ORDER BY ABS(COALESCE(return_1m_pct, 0)) DESC
    """, params)

    result = {"count": len(rows), "signals": rows}
    set_cached(cache_key, result)
    return result


@router.get("/extremes")
def extreme_signals(threshold: float = Query(1.5, description="Z-score threshold")):
    """Get indicators with extreme z-scores — the most anomalous readings."""
    cache_key = f"signals:extremes:{threshold}"
    cached = get_cached(cache_key)
    if cached:
        return cached

    rows = query_all("""
        SELECT
            source, series_key, indicator_name, country_code,
            latest_date, latest_value, unit,
            mom_pct, yoy_pct, zscore, mom_direction, zscore_label
        FROM public_marts.mart_macro_signals
        WHERE ABS(COALESCE(zscore, 0)) >= :threshold
        ORDER BY ABS(zscore) DESC
    """, {"threshold": threshold})

    result = {"threshold": threshold, "count": len(rows), "extremes": rows}
    set_cached(cache_key, result)
    return result
