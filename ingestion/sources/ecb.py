# Pontic — ECB Data Source
"""
Fetches Eurozone monetary policy data from the ECB Statistical Data Warehouse.
No API key required.

Series:
  FM.M.U2.EUR.RT.MM.EURIBOR3MD_.HSTA — Euribor 3M
  FM.M.U2.EUR.RT.MM.EURIBOR1YD_.HSTA — Euribor 1Y
  ICP.M.U2.N.000000.4.ANR            — HICP Inflation (Eurozone)
  BSP.M.U2.Y.V.AT2.A.1.U6.0000.Z01.E — ECB Balance Sheet
"""

import httpx
import pandas as pd
from datetime import datetime
import asyncio
import structlog

log = structlog.get_logger()

ECB_BASE = "https://data-api.ecb.europa.eu/service/data"

ECB_SERIES = {
    "EURIBOR_3M":    {
        "flow":   "FM",
        "key":    "M.U2.EUR.RT.MM.EURIBOR3MD_.HSTA",
        "name":   "Euribor 3-Month Rate",
        "unit":   "Percent",
    },
    "HICP_INFLATION": {
        "flow":   "ICP",
        "key":    "M.U2.N.000000.4.ANR",
        "name":   "HICP Inflation Eurozone",
        "unit":   "Percent YoY",
    },
}


async def fetch_series(
    client: httpx.AsyncClient,
    series_key: str,
    meta: dict,
    start_period: str = "2000-01",
) -> list[dict]:
    """Fetch one ECB series."""
    url = f"{ECB_BASE}/{meta['flow']}/{meta['key']}"
    params = {
        "format":      "jsondata",
        "startPeriod": start_period,
        "detail":      "dataonly",
    }
    headers = {"Accept": "application/json"}

    try:
        r = await client.get(url, params=params, headers=headers, timeout=20)
        r.raise_for_status()
        payload = r.json()

        structure = payload.get("structure", {})
        dataset   = payload.get("dataSets", [{}])[0]
        series    = dataset.get("series", {})

        time_dims = structure.get("dimensions", {}).get("observation", [{}])
        periods   = [v["id"] for v in time_dims[0].get("values", [])] if time_dims else []

        records = []
        for obs_values in series.values():
            for i, obs in obs_values.get("observations", {}).items():
                if obs and obs[0] is not None and int(i) < len(periods):
                    records.append({
                        "source":     "ECB",
                        "series_key": series_key,
                        "name":       meta["name"],
                        "unit":       meta["unit"],
                        "date":       periods[int(i)] + "-01",
                        "value":      float(obs[0]),
                        "fetched_at": datetime.utcnow().isoformat(),
                    })

        log.info("ecb.fetched", series=series_key, records=len(records))
        return records

    except Exception as e:
        log.error("ecb.error", series=series_key, error=str(e))
        return []


async def fetch_all(start_period: str = "2000-01") -> pd.DataFrame:
    """Fetch all ECB series concurrently."""
    async with httpx.AsyncClient() as client:
        tasks = [
            fetch_series(client, key, meta, start_period)
            for key, meta in ECB_SERIES.items()
        ]
        results = await asyncio.gather(*tasks)

    all_records = [r for batch in results for r in batch]
    df = pd.DataFrame(all_records)
    log.info("ecb.complete", total_records=len(df))
    return df
