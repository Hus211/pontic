#!/bin/bash
# Pontic — Layer 1: All ingestion source files

# ── ingestion/sources/fred.py ──────────────────────────────────────────────
cat > ingestion/sources/fred.py << 'EOF'
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
EOF

# ── ingestion/sources/yfinance_source.py ──────────────────────────────────
cat > ingestion/sources/yfinance.py << 'EOF'
# Pontic — Market Proxies via yfinance
"""
Fetches market proxy data as macro context signals.

Tickers:
  SPY   — S&P 500 (risk appetite)
  TLT   — 20Y Treasury ETF (long-end rates)
  DXY   — US Dollar Index (dollar strength)
  VIX   — Volatility Index (fear gauge)
  GLD   — Gold (inflation hedge / safe haven)
  XLE   — Energy sector (commodity proxy)
  EEM   — Emerging markets (global risk)
"""

import yfinance as yf
import pandas as pd
from datetime import datetime, timedelta
import structlog

log = structlog.get_logger()

TICKERS = {
    "SPY": {"name": "S&P 500 ETF",           "category": "equity",    "unit": "USD"},
    "TLT": {"name": "20Y Treasury Bond ETF",  "category": "bonds",     "unit": "USD"},
    "GLD": {"name": "Gold ETF",               "category": "commodity", "unit": "USD"},
    "XLE": {"name": "Energy Sector ETF",      "category": "equity",    "unit": "USD"},
    "EEM": {"name": "Emerging Markets ETF",   "category": "equity",    "unit": "USD"},
    "^VIX":{"name": "CBOE Volatility Index",  "category": "volatility","unit": "Index"},
    "DX-Y.NYB": {"name": "US Dollar Index",   "category": "fx",        "unit": "Index"},
}


def fetch_all(period: str = "5y", interval: str = "1d") -> pd.DataFrame:
    """Fetch all market proxy tickers and return a unified DataFrame."""
    all_records = []

    for ticker, meta in TICKERS.items():
        try:
            data = yf.download(ticker, period=period, interval=interval,
                               progress=False, auto_adjust=True)
            if data.empty:
                log.warning("yfinance.empty", ticker=ticker)
                continue

            for date, row in data.iterrows():
                all_records.append({
                    "source":     "YFINANCE",
                    "series_key": ticker.replace("^", "").replace("-", "_").replace(".", "_"),
                    "ticker":     ticker,
                    "name":       meta["name"],
                    "category":   meta["category"],
                    "unit":       meta["unit"],
                    "date":       date.strftime("%Y-%m-%d"),
                    "value":      round(float(row["Close"]), 4),
                    "volume":     float(row.get("Volume", 0)),
                    "fetched_at": datetime.utcnow().isoformat(),
                })

            log.info("yfinance.fetched", ticker=ticker, records=len(data))

        except Exception as e:
            log.error("yfinance.error", ticker=ticker, error=str(e))

    df = pd.DataFrame(all_records)
    log.info("yfinance.complete", total_records=len(df))
    return df
EOF

# ── ingestion/sources/worldbank.py ─────────────────────────────────────────
cat > ingestion/sources/worldbank.py << 'EOF'
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
EOF

# ── ingestion/sources/ecb.py ───────────────────────────────────────────────
cat > ingestion/sources/ecb.py << 'EOF'
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
EOF

# ── ingestion/sources/oecd.py ──────────────────────────────────────────────
cat > ingestion/sources/oecd.py << 'EOF'
# Pontic — OECD Data Source
"""
Fetches composite leading indicators and PMI-adjacent data from OECD.
No API key required.

Series:
  CLI — Composite Leading Indicator (amplitude adjusted)
  MEI_CLI — Main Economic Indicators
"""

import httpx
import pandas as pd
from datetime import datetime
import asyncio
import structlog

log = structlog.get_logger()

OECD_BASE = "https://sdmx.oecd.org/public/rest/data"

OECD_SERIES = {
    "CLI": {
        "dataset": "MEI_CLI",
        "key":     "LOLITOAA.{country}.M",
        "name":    "Composite Leading Indicator",
        "unit":    "Index",
    },
}

COUNTRIES = ["USA", "GBR", "DEU", "FRA", "JPN", "CHN", "CAN", "AUS", "BRA", "IND"]


async def fetch_cli(
    client: httpx.AsyncClient,
    country: str,
    start_period: str = "2000-01",
) -> list[dict]:
    """Fetch CLI for one country."""
    key = f"MEI_CLI/LOLITOAA.{country}.M"
    url = f"{OECD_BASE}/{key}"
    params = {
        "startPeriod": start_period,
        "format":      "jsondata",
    }
    headers = {"Accept": "application/vnd.sdmx.data+json;version=1.0"}

    try:
        r = await client.get(url, params=params, headers=headers, timeout=25)
        r.raise_for_status()
        payload = r.json()

        dims   = payload["data"]["structures"][0]["dimensions"]["observation"]
        periods= [v["id"] for v in dims[0]["values"]]
        series_data = payload["data"]["dataSets"][0]["series"]

        records = []
        for obs_map in series_data.values():
            for idx, val in obs_map.get("observations", {}).items():
                if val and val[0] is not None and int(idx) < len(periods):
                    records.append({
                        "source":       "OECD",
                        "series_key":   "CLI",
                        "name":         "Composite Leading Indicator",
                        "country_code": country,
                        "unit":         "Index",
                        "date":         periods[int(idx)] + "-01",
                        "value":        float(val[0]),
                        "fetched_at":   datetime.utcnow().isoformat(),
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
EOF

# ── ingestion/sources/bls.py ───────────────────────────────────────────────
cat > ingestion/sources/bls.py << 'EOF'
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
EOF

echo "✅ All ingestion sources written"
