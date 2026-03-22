#!/bin/bash
# Pontic — Layer 1 Pipeline: Prefect flows + DB writer

# ── pipeline/flows.py ──────────────────────────────────────────────────────
cat > pipeline/flows.py << 'EOF'
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
EOF

# ── pipeline/writer.py ─────────────────────────────────────────────────────
cat > pipeline/writer.py << 'EOF'
# Pontic — Postgres Writer
"""
Handles upsert logic for all ingestion tables.
Uses SQLAlchemy core for fast bulk operations.
"""

import os
from datetime import datetime

import pandas as pd
from sqlalchemy import create_engine, text
from dotenv import load_dotenv

load_dotenv()


def get_engine():
    url = (
        f"postgresql://{os.getenv('POSTGRES_USER', 'pontic')}:"
        f"{os.getenv('POSTGRES_PASSWORD', 'pontic_dev')}@"
        f"{os.getenv('POSTGRES_HOST', 'localhost')}:"
        f"{os.getenv('POSTGRES_PORT', '5432')}/"
        f"{os.getenv('POSTGRES_DB', 'pontic')}"
    )
    return create_engine(url, pool_pre_ping=True)


def ensure_tables(engine) -> None:
    """Create tables if they don't exist."""
    with engine.connect() as conn:
        conn.execute(text("""
            CREATE TABLE IF NOT EXISTS raw_indicators (
                id              BIGSERIAL PRIMARY KEY,
                source          VARCHAR(50)  NOT NULL,
                series_key      VARCHAR(100) NOT NULL,
                series_id       VARCHAR(100),
                name            TEXT,
                unit            VARCHAR(100),
                frequency       VARCHAR(50),
                country_code    VARCHAR(10)  DEFAULT 'US',
                date            DATE         NOT NULL,
                value           DOUBLE PRECISION NOT NULL,
                fetched_at      TIMESTAMPTZ  DEFAULT NOW(),
                UNIQUE (source, series_key, country_code, date)
            );
        """))

        conn.execute(text("""
            CREATE TABLE IF NOT EXISTS raw_country_indicators (
                id              BIGSERIAL PRIMARY KEY,
                source          VARCHAR(50)  NOT NULL,
                series_key      VARCHAR(100) NOT NULL,
                indicator_id    VARCHAR(100),
                name            TEXT,
                unit            VARCHAR(100),
                country_code    VARCHAR(10)  NOT NULL,
                country_name    VARCHAR(100),
                date            DATE         NOT NULL,
                value           DOUBLE PRECISION NOT NULL,
                fetched_at      TIMESTAMPTZ  DEFAULT NOW(),
                UNIQUE (source, series_key, country_code, date)
            );
        """))

        conn.execute(text("""
            CREATE TABLE IF NOT EXISTS raw_market_proxies (
                id              BIGSERIAL PRIMARY KEY,
                source          VARCHAR(50)  NOT NULL,
                series_key      VARCHAR(100) NOT NULL,
                ticker          VARCHAR(20),
                name            TEXT,
                category        VARCHAR(50),
                unit            VARCHAR(50),
                date            DATE         NOT NULL,
                value           DOUBLE PRECISION NOT NULL,
                volume          DOUBLE PRECISION,
                fetched_at      TIMESTAMPTZ  DEFAULT NOW(),
                UNIQUE (source, series_key, date)
            );
        """))

        conn.execute(text("""
            CREATE TABLE IF NOT EXISTS ingestion_runs (
                id          BIGSERIAL PRIMARY KEY,
                run_at      TIMESTAMPTZ DEFAULT NOW(),
                status      VARCHAR(20),
                total_rows  INTEGER,
                details     JSONB
            );
        """))

        conn.commit()


def upsert_dataframe(df: pd.DataFrame, table: str) -> int:
    """
    Upsert DataFrame rows into Postgres.
    On conflict (unique key) — update value and fetched_at.
    Returns number of rows written.
    """
    if df.empty:
        return 0

    engine = get_engine()
    ensure_tables(engine)

    df = df.copy()
    df["fetched_at"] = datetime.utcnow()

    # Determine conflict columns by table
    conflict_cols = {
        "raw_indicators":         "(source, series_key, country_code, date)",
        "raw_country_indicators": "(source, series_key, country_code, date)",
        "raw_market_proxies":     "(source, series_key, date)",
    }.get(table, "(source, series_key, date)")

    # Write to temp table then upsert
    temp_table = f"_tmp_{table}"
    with engine.connect() as conn:
        df.to_sql(temp_table, conn, if_exists="replace", index=False, method="multi")
        conn.execute(text(f"""
            INSERT INTO {table}
            SELECT * FROM {temp_table}
            ON CONFLICT {conflict_cols}
            DO UPDATE SET
                value      = EXCLUDED.value,
                fetched_at = EXCLUDED.fetched_at;
        """))
        conn.execute(text(f"DROP TABLE IF EXISTS {temp_table}"))
        conn.commit()

    return len(df)
EOF

# ── pipeline/schedules.py ──────────────────────────────────────────────────
cat > pipeline/schedules.py << 'EOF'
# Pontic — Prefect Schedule Definitions
"""
Defines refresh schedules for Pontic data flows.

Usage:
    python pipeline/schedules.py   # deploy schedules to Prefect
"""

from prefect import serve
from prefect.schedules import Interval
from datetime import timedelta
from pipeline.flows import macro_refresh_flow


def deploy():
    """Deploy the macro refresh flow with a 3-minute interval schedule."""
    macro_refresh_flow.serve(
        name="pontic-macro-refresh-scheduled",
        interval=timedelta(minutes=3),
        tags=["pontic", "macro", "production"],
        description="Refreshes all Pontic macro data sources every 3 minutes",
    )


if __name__ == "__main__":
    deploy()
EOF

echo "✅ Pipeline files written"
