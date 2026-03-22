# Pontic — Prefect Pipeline Flows
"""
Orchestrates all 6 ingestion sources and writes to PostgreSQL.

Usage:
    python pipeline/flows.py              # run once immediately
    prefect deploy pipeline/flows.py      # schedule via Prefect UI
"""

import asyncio
import os
from datetime import datetime

import pandas as pd
from prefect import flow, task, get_run_logger
from dotenv import load_dotenv

load_dotenv()

# ── Tasks — one per source ─────────────────────────────────────────────────

@task(name="ingest-fred", retries=3, retry_delay_seconds=30)
async def ingest_fred() -> pd.DataFrame:
    from ingestion.sources.fred import fetch_all
    api_key = os.getenv("FRED_API_KEY")
    if not api_key:
        raise ValueError("FRED_API_KEY not set in .env")
    return await fetch_all(api_key)


@task(name="ingest-yfinance", retries=2, retry_delay_seconds=15)
def ingest_yfinance() -> pd.DataFrame:
    from ingestion.sources.yfinance import fetch_all
    return fetch_all(period="5y")


@task(name="ingest-worldbank", retries=3, retry_delay_seconds=30)
async def ingest_worldbank() -> pd.DataFrame:
    from ingestion.sources.worldbank import fetch_all
    return await fetch_all()


@task(name="ingest-ecb", retries=3, retry_delay_seconds=30)
async def ingest_ecb() -> pd.DataFrame:
    from ingestion.sources.ecb import fetch_all
    return await fetch_all()


@task(name="ingest-oecd", retries=3, retry_delay_seconds=30)
async def ingest_oecd() -> pd.DataFrame:
    from ingestion.sources.oecd import fetch_all
    return await fetch_all()


@task(name="ingest-bls", retries=3, retry_delay_seconds=30)
async def ingest_bls() -> pd.DataFrame:
    from ingestion.sources.bls import fetch_all
    return await fetch_all()


@task(name="write-to-postgres")
def write_to_postgres(df: pd.DataFrame, table: str) -> int:
    """Write a DataFrame to Postgres using upsert logic."""
    from pipeline.writer import upsert_dataframe
    if df.empty:
        return 0
    rows = upsert_dataframe(df, table)
    return rows


@task(name="compute-derived-signals")
def compute_signals() -> None:
    """Trigger dbt to recompute derived models after ingestion."""
    import subprocess
    result = subprocess.run(
        ["dbt", "run", "--project-dir", "warehouse", "--profiles-dir", "warehouse"],
        capture_output=True, text=True
    )
    if result.returncode != 0:
        raise RuntimeError(f"dbt run failed:\n{result.stderr}")


# ── Main flow ──────────────────────────────────────────────────────────────

@flow(name="pontic-macro-refresh", log_prints=True)
async def macro_refresh_flow():
    """
    Full macro data refresh — runs all 6 sources concurrently,
    writes to Postgres, then triggers dbt transformations.
    """
    logger = get_run_logger()
    logger.info(f"Starting Pontic macro refresh — {datetime.utcnow().isoformat()}")

    # Run all async sources concurrently
    fred_df, wb_df, ecb_df, oecd_df, bls_df = await asyncio.gather(
        ingest_fred(),
        ingest_worldbank(),
        ingest_ecb(),
        ingest_oecd(),
        ingest_bls(),
    )

    # yfinance is sync — run separately
    yf_df = ingest_yfinance()

    # Write all to Postgres
    results = {
        "fred":       write_to_postgres(fred_df,  "raw_indicators"),
        "worldbank":  write_to_postgres(wb_df,    "raw_country_indicators"),
        "ecb":        write_to_postgres(ecb_df,   "raw_indicators"),
        "oecd":       write_to_postgres(oecd_df,  "raw_country_indicators"),
        "bls":        write_to_postgres(bls_df,   "raw_indicators"),
        "yfinance":   write_to_postgres(yf_df,    "raw_market_proxies"),
    }

    total = sum(results.values())
    logger.info(f"Ingestion complete — {total:,} rows written")
    for source, rows in results.items():
        logger.info(f"  {source}: {rows:,} rows")

    # Recompute dbt models
    compute_signals()
    logger.info("dbt models refreshed")

    return results


if __name__ == "__main__":
    asyncio.run(macro_refresh_flow())