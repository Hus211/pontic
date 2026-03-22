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


# Columns to insert (excluding BIGSERIAL id). Must match CREATE TABLE order intent, not positional SELECT *.
TABLE_INSERT_COLS: dict[str, tuple[str, ...]] = {
    "raw_indicators": (
        "source",
        "series_key",
        "series_id",
        "name",
        "unit",
        "frequency",
        "country_code",
        "date",
        "value",
        "fetched_at",
    ),
    "raw_country_indicators": (
        "source",
        "series_key",
        "indicator_id",
        "name",
        "unit",
        "country_code",
        "country_name",
        "date",
        "value",
        "fetched_at",
    ),
    "raw_market_proxies": (
        "source",
        "series_key",
        "ticker",
        "name",
        "category",
        "unit",
        "date",
        "value",
        "volume",
        "fetched_at",
    ),
}


def _align_dataframe_to_table(df: pd.DataFrame, table: str) -> pd.DataFrame:
    """Ensure DataFrame has exactly the target columns (missing → NA)."""
    cols = TABLE_INSERT_COLS[table]
    out = df.copy()
    for c in cols:
        if c not in out.columns:
            out[c] = pd.NA
    return out[list(cols)]


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

    df = _align_dataframe_to_table(df, table)
    df = df.copy()
    if table == "raw_indicators":
        df["country_code"] = df["country_code"].fillna("US")
    df["fetched_at"] = datetime.utcnow()

    insert_cols = TABLE_INSERT_COLS[table]
    col_list = ", ".join(insert_cols)
    # Named insert so id is generated by BIGSERIAL; values align by column name.
    select_list = ", ".join(insert_cols)

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
            INSERT INTO {table} ({col_list})
            SELECT {select_list} FROM {temp_table}
            ON CONFLICT {conflict_cols}
            DO UPDATE SET
                value      = EXCLUDED.value,
                fetched_at = EXCLUDED.fetched_at;
        """))
        conn.execute(text(f"DROP TABLE IF EXISTS {temp_table}"))
        conn.commit()

    return len(df)