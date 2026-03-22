# Pontic — BLS Data Source
"""
Fetches US labour market data from the Bureau of Labor Statistics.
No API key required for public series.

Series:
  CES0000000001 — Total Nonfarm Payrolls
  LNS14000000   — Unemployment Rate
  CES0500000003 — Average Hourly Earnings
  LNS11300000   — Labour Force Participation Rate
  CUUR0000SA0   — CPI-U All Items
"""

import httpx
import pandas as pd
from datetime import datetime
import structlog

log = structlog.get_logger()

BLS_BASE = "https://api.bls.gov/publicAPI/v2/timeseries/data/"

BLS_SERIES = {
    "NONFARM_PAYROLLS":       {"id": "CES0000000001", "name": "Total Nonfarm Payrolls",         "unit": "Thousands"},
    "UNEMPLOYMENT_RATE":      {"id": "LNS14000000",   "name": "Unemployment Rate",              "unit": "Percent"},
    "AVG_HOURLY_EARNINGS":    {"id": "CES0500000003", "name": "Average Hourly Earnings",        "unit": "USD/Hour"},
    "LABOUR_PARTICIPATION":   {"id": "LNS11300000",   "name": "Labour Force Participation",     "unit": "Percent"},
    "CPI_U":                  {"id": "CUUR0000SA0",   "name": "CPI-U All Items",                "unit": "Index"},
}

MONTH_MAP = {
    "M01":"01","M02":"02","M03":"03","M04":"04","M05":"05","M06":"06",
    "M07":"07","M08":"08","M09":"09","M10":"10","M11":"11","M12":"12",
}


async def fetch_all(start_year: int = 2000) -> pd.DataFrame:
    """Fetch all BLS series in a single API call."""
    series_ids  = [v["id"] for v in BLS_SERIES.values()]
    series_meta = {v["id"]: {"key": k, **v} for k, v in BLS_SERIES.items()}

    payload = {
        "seriesid":  series_ids,
        "startyear": str(start_year),
        "endyear":   str(datetime.now().year),
        "catalog":   False,
        "calculations": True,
        "annualaverage": False,
    }

    try:
        async with httpx.AsyncClient() as client:
            r = await client.post(BLS_BASE, json=payload, timeout=30)
            r.raise_for_status()
            data = r.json()

        records = []
        for series in data.get("Results", {}).get("series", []):
            sid  = series["seriesID"]
            meta = series_meta.get(sid, {})
            for obs in series.get("data", []):
                month = MONTH_MAP.get(obs.get("period", ""), None)
                if not month or obs.get("value") in ("", "-"):
                    continue
                records.append({
                    "source":     "BLS",
                    "series_key": meta.get("key", sid),
                    "series_id":  sid,
                    "name":       meta.get("name", sid),
                    "unit":       meta.get("unit", ""),
                    "date":       f"{obs['year']}-{month}-01",
                    "value":      float(obs["value"].replace(",", "")),
                    "fetched_at": datetime.utcnow().isoformat(),
                })

        df = pd.DataFrame(records)
        log.info("bls.complete", total_records=len(df))
        return df

    except Exception as e:
        log.error("bls.error", error=str(e))
        return pd.DataFrame()
