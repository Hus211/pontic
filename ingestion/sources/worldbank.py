# Pontic — World Bank Data Source
"""
Fetches global macro indicators from the World Bank API.
No API key required.

Indicators:
  NY.GDP.MKTP.CD  — GDP (current USD)
  FP.CPI.TOTL.ZG  — CPI inflation %
  GC.DOD.TOTL.GD.ZS — Debt to GDP %
  BX.KLT.DINV.CD.WD — FDI inflows
  SL.UEM.TOTL.ZS  — Unemployment %
"""

import httpx
import pandas as pd
from datetime import datetime
import asyncio
import structlog

log = structlog.get_logger()

WB_BASE = "https://api.worldbank.org/v2/country/{country}/indicator/{indicator}"

INDICATORS = {
    "GDP_USD":       "NY.GDP.MKTP.CD",
    "CPI_INFLATION": "FP.CPI.TOTL.ZG",
    "DEBT_TO_GDP":   "GC.DOD.TOTL.GD.ZS",
    "FDI_INFLOWS":   "BX.KLT.DINV.CD.WD",
    "UNEMPLOYMENT":  "SL.UEM.TOTL.ZS",
}

COUNTRIES = {
    "US": "United States",
    "GB": "United Kingdom",
    "DE": "Germany",
    "FR": "France",
    "JP": "Japan",
    "CN": "China",
    "IN": "India",
    "BR": "Brazil",
    "CA": "Canada",
    "AU": "Australia",
    "EU": "Euro Area",
}


async def fetch_indicator(
    client: httpx.AsyncClient,
    country_code: str,
    indicator_key: str,
    indicator_id: str,
    start_year: int = 2000,
) -> list[dict]:
    """Fetch one indicator for one country."""
    url = WB_BASE.format(country=country_code, indicator=indicator_id)
    params = {
        "format":    "json",
        "per_page":  100,
        "mrv":       25,
        "date":      f"{start_year}:{datetime.now().year}",
    }
    try:
        r = await client.get(url, params=params, timeout=20)
        r.raise_for_status()
        payload = r.json()

        if len(payload) < 2 or not payload[1]:
            return []

        records = []
        for entry in payload[1]:
            if entry.get("value") is None:
                continue
            records.append({
                "source":        "WORLD_BANK",
                "series_key":    indicator_key,
                "indicator_id":  indicator_id,
                "country_code":  country_code,
                "country_name":  COUNTRIES.get(country_code, country_code),
                "date":          f"{entry['date']}-01-01",
                "value":         float(entry["value"]),
                "fetched_at":    datetime.utcnow().isoformat(),
            })

        log.info("worldbank.fetched", country=country_code,
                 indicator=indicator_key, records=len(records))
        return records

    except Exception as e:
        log.error("worldbank.error", country=country_code,
                  indicator=indicator_key, error=str(e))
        return []


async def fetch_all(start_year: int = 2000) -> pd.DataFrame:
    """Fetch all indicators for all countries concurrently."""
    async with httpx.AsyncClient() as client:
        tasks = [
            fetch_indicator(client, country, ind_key, ind_id, start_year)
            for country in COUNTRIES
            for ind_key, ind_id in INDICATORS.items()
        ]
        results = await asyncio.gather(*tasks)

    all_records = [r for batch in results for r in batch]
    df = pd.DataFrame(all_records)
    log.info("worldbank.complete", total_records=len(df))
    return df
