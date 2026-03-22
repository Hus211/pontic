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

            # yfinance ≥0.2 returns MultiIndex columns (Price, Ticker); flatten for scalar row access.
            if isinstance(data.columns, pd.MultiIndex):
                data = data.copy()
                data.columns = data.columns.droplevel(1)

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
                    "volume":     float(v) if (v := row.get("Volume")) is not None and pd.notna(v) else 0.0,
                    "fetched_at": datetime.utcnow().isoformat(),
                })

            log.info("yfinance.fetched", ticker=ticker, records=len(data))

        except Exception as e:
            log.error("yfinance.error", ticker=ticker, error=str(e))

    df = pd.DataFrame(all_records)
    log.info("yfinance.complete", total_records=len(df))
    return df
