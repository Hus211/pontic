# Pontic — Macro Regime Router
"""
Classifies the current macro regime based on growth + inflation signals.

Regimes:
  GOLDILOCKS   — Growth up, Inflation down  (best for risk assets)
  REFLATION    — Growth up, Inflation up    (commodities, value)
  STAGFLATION  — Growth down, Inflation up  (worst regime)
  DEFLATION    — Growth down, Inflation down (bonds, defensive)
"""

from fastapi import APIRouter
from api.services.db import query_one, query_all
from api.services.cache import get_cached, set_cached

router = APIRouter(prefix="/regime", tags=["Regime"])


def classify_regime(gdp_yoy: float | None, cpi_yoy: float | None) -> dict:
    """Simple 2x2 regime classification."""
    if gdp_yoy is None or cpi_yoy is None:
        return {"regime": "UNKNOWN", "confidence": "LOW"}

    growth_up    = gdp_yoy  > 0
    inflation_up = cpi_yoy  > 2.5  # Fed target as threshold

    if growth_up and not inflation_up:
        regime = "GOLDILOCKS"
        desc   = "Growth expanding, inflation contained. Historically favourable for equities."
    elif growth_up and inflation_up:
        regime = "REFLATION"
        desc   = "Growth expanding but inflation elevated. Commodities, value stocks, and TIPS tend to outperform."
    elif not growth_up and inflation_up:
        regime = "STAGFLATION"
        desc   = "Growth slowing with elevated inflation. Most challenging macro environment."
    else:
        regime = "DEFLATION"
        desc   = "Growth and inflation both declining. Bonds and defensive assets typically outperform."

    return {
        "regime":      regime,
        "description": desc,
        "gdp_yoy_pct": gdp_yoy,
        "cpi_yoy_pct": cpi_yoy,
        "growth_up":   growth_up,
        "inflation_up": inflation_up,
    }


@router.get("/current")
def current_regime():
    """Get the current macro regime classification for the US."""
    cache_key = "regime:current"
    cached = get_cached(cache_key)
    if cached:
        return cached

    # Pull latest GDP and CPI signals
    gdp = query_one("""
        SELECT yoy_pct FROM public_marts.mart_macro_signals
        WHERE series_key = 'GDP' AND country_code = 'US'
    """)
    cpi = query_one("""
        SELECT yoy_pct FROM public_marts.mart_macro_signals
        WHERE series_key = 'CPI' AND country_code = 'US'
    """)

    gdp_yoy = gdp["yoy_pct"] if gdp else None
    cpi_yoy = cpi["yoy_pct"] if cpi else None

    regime = classify_regime(gdp_yoy, cpi_yoy)

    # Add supporting signals
    signals = query_all("""
        SELECT series_key, indicator_name, latest_value, unit,
               mom_pct, yoy_pct, zscore, zscore_label
        FROM public_marts.mart_macro_signals
        WHERE series_key IN ('GDP','CPI','FED_FUNDS','UNEMPLOYMENT','TREASURY_10Y')
          AND country_code = 'US'
        ORDER BY series_key
    """)

    result = {**regime, "supporting_signals": signals}
    set_cached(cache_key, result)
    return result
