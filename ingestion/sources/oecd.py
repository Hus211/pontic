# Pontic — OECD Data Source
"""
Fetches composite leading indicators from OECD (via DBnomics; direct OECD SDMX
URLs for MEI_CLI often 404 after infrastructure changes).

Series: MEI_CLI — Composite Leading Indicator (amplitude adjusted), monthly.
"""

import httpx
import pandas as pd
from datetime import datetime
import asyncio
import structlog

log = structlog.get_logger()

# DBnomics mirrors OECD/MEI_CLI with stable JSON — see https://db.nomics.world/OECD/MEI_CLI
DBNOMICS_BASE = "https://api.db.nomics.world/v22/series/OECD/MEI_CLI"

COUNTRIES = ["USA", "GBR", "DEU", "FRA", "JPN", "CHN", "CAN", "AUS", "BRA", "IND"]


async def fetch_cli(
    client: httpx.AsyncClient,
    country: str,
    start_period: str = "2000-01",
) -> list[dict]:
    """Fetch CLI for one country."""
    series_code = f"LOLITOAA.{country}.M"
    url = f"{DBNOMICS_BASE}/{series_code}"
    params = {"observations": "1", "limit": "1"}

    try:
        r = await client.get(url, params=params, timeout=25)
        r.raise_for_status()
        payload = r.json()

        docs = payload.get("series", {}).get("docs", [])
        if not docs:
            log.warning("oecd.empty_response", country=country)
            return []

        doc = docs[0]
        periods = doc.get("period") or []
        values = doc.get("value") or []
        start_cmp = start_period[:7]

        records = []
        for period, val in zip(periods, values):
            if period < start_cmp:
                continue
            if val is None:
                continue
            records.append({
                "source":        "OECD",
                "series_key":    "CLI",
                "indicator_id":  "LOLITOAA",
                "name":          "Composite Leading Indicator",
                "country_code":  country,
                "unit":          "Index",
                "date":          f"{period}-01",
                "value":         float(val),
                "fetched_at":    datetime.utcnow().isoformat(),
            })

        log.info("oecd.fetched", country=country, records=len(records))
        return records

    except Exception as e:
        log.error("oecd.error", country=country, error=str(e))
        return []


async def fetch_all(start_period: str = "2000-01") -> pd.DataFrame:
    """Fetch CLI for all countries concurrently."""
    async with httpx.AsyncClient() as client:
        tasks = [fetch_cli(client, c, start_period) for c in COUNTRIES]
        results = await asyncio.gather(*tasks)

    all_records = [r for batch in results for r in batch]
    df = pd.DataFrame(all_records)
    log.info("oecd.complete", total_records=len(df))
    return df
