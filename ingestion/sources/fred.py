# Pontic — FRED Data Source
"""
Fetches macro indicators from the Federal Reserve Economic Data API.
API Key required: https://fred.stlouisfed.org/docs/api/api_key.html

Indicators fetched:
  GDP, CPI, PCE, Fed Funds Rate, Unemployment, M2, 10Y Treasury,
  Yield Curve (10Y-2Y spread), Industrial Production, Retail Sales
"""

import httpx
import pandas as pd
from datetime import datetime
from typing import Optional
import structlog

log = structlog.get_logger()

FRED_BASE = "https://api.stlouisfed.org/fred/series/observations"

FRED_SERIES = {
    "GDP":              {"id": "GDP",       "name": "US GDP",                    "unit": "Billions USD",  "frequency": "quarterly"},
    "CPI":              {"id": "CPIAUCSL",  "name": "CPI All Items",             "unit": "Index",         "frequency": "monthly"},
    "PCE":              {"id": "PCE",       "name": "Personal Consumption Exp.", "unit": "Billions USD",  "frequency": "monthly"},
    "FED_FUNDS":        {"id": "FEDFUNDS",  "name": "Federal Funds Rate",        "unit": "Percent",       "frequency": "monthly"},
    "UNEMPLOYMENT":     {"id": "UNRATE",    "name": "Unemployment Rate",         "unit": "Percent",       "frequency": "monthly"},
    "M2":               {"id": "M2SL",      "name": "M2 Money Supply",           "unit": "Billions USD",  "frequency": "monthly"},
    "TREASURY_10Y":     {"id": "GS10",      "name": "10-Year Treasury Yield",    "unit": "Percent",       "frequency": "monthly"},
    "TREASURY_2Y":      {"id": "GS2",       "name": "2-Year Treasury Yield",     "unit": "Percent",       "frequency": "monthly"},
    "INDUSTRIAL_PROD":  {"id": "INDPRO",    "name": "Industrial Production",     "unit": "Index",         "frequency": "monthly"},
    "RETAIL_SALES":     {"id": "RSXFS",     "name": "Retail Sales ex Food",      "unit": "Millions USD",  "frequency": "monthly"},
    "HOUSING_STARTS":   {"id": "HOUST",     "name": "Housing Starts",            "unit": "Thousands",     "frequency": "monthly"},
    "CONSUMER_SENT":    {"id": "UMCSENT",   "name": "Consumer Sentiment",        "unit": "Index",         "frequency": "monthly"},
}


async def fetch_series(
    client: httpx.AsyncClient,
    series_key: str,
    api_key: str,
    observation_start: str = "2000-01-01",
) -> list[dict]:
    """Fetch a single FRED series and return normalised records."""
    meta = FRED_SERIES[series_key]
    params = {
        "series_id":          meta["id"],
        "api_key":            api_key,
        "file_type":          "json",
        "observation_start":  observation_start,
        "sort_order":         "desc",
    }
    try:
        r = await client.get(FRED_BASE, params=params, timeout=15)
        r.raise_for_status()
        data = r.json()

        records = []
        for obs in data.get("observations", []):
            if obs["value"] == ".":
                continue
            records.append({
                "source":     "FRED",
                "series_key": series_key,
                "series_id":  meta["id"],
                "name":       meta["name"],
                "unit":       meta["unit"],
                "frequency":  meta["frequency"],
                "date":       obs["date"],
                "value":      float(obs["value"]),
                "fetched_at": datetime.utcnow().isoformat(),
            })

        log.info("fred.fetched", series=series_key, records=len(records))
        return records

    except Exception as e:
        log.error("fred.error", series=series_key, error=str(e))
        return []


async def fetch_all(api_key: str, observation_start: str = "2000-01-01") -> pd.DataFrame:
    """Fetch all FRED series concurrently and return a unified DataFrame."""
    import asyncio

    async with httpx.AsyncClient() as client:
        tasks = [
            fetch_series(client, key, api_key, observation_start)
            for key in FRED_SERIES
        ]
        results = await asyncio.gather(*tasks)

    all_records = [r for batch in results for r in batch]
    df = pd.DataFrame(all_records)
    log.info("fred.complete", total_records=len(df), series_count=len(FRED_SERIES))
    return df
