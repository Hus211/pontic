# Pontic — Database Service

from sqlalchemy import create_engine, text
from sqlalchemy.pool import QueuePool
from api.config import get_settings
import pandas as pd

settings = get_settings()

engine = create_engine(
    settings.database_url,
    poolclass=QueuePool,
    pool_size=10,
    max_overflow=20,
    pool_pre_ping=True,
)


def query_df(sql: str, params: dict = None) -> pd.DataFrame:
    """Execute a SQL query and return a DataFrame."""
    with engine.connect() as conn:
        result = conn.execute(text(sql), params or {})
        return pd.DataFrame(result.fetchall(), columns=result.keys())


def query_one(sql: str, params: dict = None) -> dict | None:
    """Execute a SQL query and return a single row as dict."""
    with engine.connect() as conn:
        result = conn.execute(text(sql), params or {})
        row = result.fetchone()
        return dict(row._mapping) if row else None


def query_all(sql: str, params: dict = None) -> list[dict]:
    """Execute a SQL query and return all rows as list of dicts."""
    with engine.connect() as conn:
        result = conn.execute(text(sql), params or {})
        return [dict(row._mapping) for row in result.fetchall()]
