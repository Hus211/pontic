# Pontic — Countries Router

from fastapi import APIRouter, HTTPException
from api.services.db import query_all, query_one
from api.services.cache import get_cached, set_cached

router = APIRouter(prefix="/countries", tags=["Countries"])


@router.get("/")
def list_countries():
    """List all countries with latest macro snapshot."""
    cache_key = "countries:all"
    cached = get_cached(cache_key)
    if cached:
        return cached

    rows = query_all("""
        SELECT
            country_code, country_name, latest_date,
            gdp_trillions_usd, cpi_inflation_pct, debt_to_gdp_pct,
            unemployment_pct, fdi_inflows_billions_usd, cli_index,
            growth_signal
        FROM public_marts.mart_country_snapshot
        ORDER BY gdp_trillions_usd DESC NULLS LAST
    """)

    result = {"count": len(rows), "countries": rows}
    set_cached(cache_key, result)
    return result


@router.get("/{country_code}")
def get_country(country_code: str):
    """Get full macro snapshot for a specific country."""
    cache_key = f"country:{country_code.upper()}"
    cached = get_cached(cache_key)
    if cached:
        return cached

    row = query_one("""
        SELECT *
        FROM public_marts.mart_country_snapshot
        WHERE country_code = :code
    """, {"code": country_code.upper()})

    if not row:
        raise HTTPException(status_code=404, detail=f"Country '{country_code}' not found")

    set_cached(cache_key, row)
    return row
