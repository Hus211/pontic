#!/bin/bash
# Pontic — Layer 3: FastAPI Backend

# ── api/config.py ──────────────────────────────────────────────────────────
cat > api/config.py << 'EOF'
# Pontic — API Configuration

from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    postgres_host:     str = "localhost"
    postgres_port:     int = 5432
    postgres_db:       str = "pontic"
    postgres_user:     str = "pontic"
    postgres_password: str = "pontic_dev"
    redis_url:         str = "redis://localhost:6379"
    cache_ttl_seconds: int = 180
    api_env:           str = "development"

    @property
    def database_url(self) -> str:
        return (
            f"postgresql://{self.postgres_user}:{self.postgres_password}"
            f"@{self.postgres_host}:{self.postgres_port}/{self.postgres_db}"
        )

    model_config = {"env_file": ".env", "extra": "ignore"}


@lru_cache
def get_settings() -> Settings:
    return Settings()
EOF

# ── api/services/db.py ─────────────────────────────────────────────────────
cat > api/services/db.py << 'EOF'
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
EOF

# ── api/services/cache.py ──────────────────────────────────────────────────
cat > api/services/cache.py << 'EOF'
# Pontic — Redis Cache Service

import json
import redis
from functools import wraps
from typing import Callable, Any
from api.config import get_settings

settings = get_settings()

try:
    redis_client = redis.from_url(settings.redis_url, decode_responses=True)
    redis_client.ping()
except Exception:
    redis_client = None


def cache(ttl: int = None):
    """Decorator — caches function result in Redis by cache key."""
    def decorator(fn: Callable) -> Callable:
        @wraps(fn)
        def wrapper(*args, cache_key: str = None, **kwargs) -> Any:
            if not redis_client or not cache_key:
                return fn(*args, **kwargs)

            cached = redis_client.get(cache_key)
            if cached:
                return json.loads(cached)

            result = fn(*args, **kwargs)
            redis_client.setex(
                cache_key,
                ttl or settings.cache_ttl_seconds,
                json.dumps(result, default=str)
            )
            return result
        return wrapper
    return decorator


def invalidate(pattern: str) -> int:
    """Delete all Redis keys matching a pattern."""
    if not redis_client:
        return 0
    keys = redis_client.keys(pattern)
    if keys:
        return redis_client.delete(*keys)
    return 0


def get_cached(key: str) -> Any | None:
    if not redis_client:
        return None
    val = redis_client.get(key)
    return json.loads(val) if val else None


def set_cached(key: str, value: Any, ttl: int = None) -> None:
    if not redis_client:
        return
    redis_client.setex(
        key,
        ttl or settings.cache_ttl_seconds,
        json.dumps(value, default=str)
    )
EOF

# ── api/dependencies.py ────────────────────────────────────────────────────
cat > api/dependencies.py << 'EOF'
# Pontic — FastAPI Dependencies

from api.config import get_settings, Settings
from fastapi import Depends

def get_config() -> Settings:
    return get_settings()
EOF

# ── api/routers/indicators.py ──────────────────────────────────────────────
cat > api/routers/indicators.py << 'EOF'
# Pontic — Indicators Router

from fastapi import APIRouter, Query
from api.services.db import query_all, query_one
from api.services.cache import get_cached, set_cached
from api.config import get_settings

router   = APIRouter(prefix="/indicators", tags=["Indicators"])
settings = get_settings()


@router.get("/")
def list_indicators(
    source:  str | None = Query(None, description="Filter by source e.g. FRED"),
    country: str | None = Query(None, description="Filter by country code e.g. US"),
):
    """List all macro indicators with latest values and signals."""
    cache_key = f"indicators:{source}:{country}"
    cached = get_cached(cache_key)
    if cached:
        return cached

    where = "WHERE 1=1"
    params = {}
    if source:
        where  += " AND source = :source"
        params["source"] = source.upper()
    if country:
        where  += " AND country_code = :country"
        params["country"] = country.upper()

    rows = query_all(f"""
        SELECT
            source, series_key, indicator_name, unit, frequency,
            country_code, latest_date, latest_value,
            mom_pct, yoy_pct, zscore, mom_direction, zscore_label,
            fetched_at
        FROM public_marts.mart_macro_signals
        {where}
        ORDER BY ABS(COALESCE(zscore, 0)) DESC
    """, params)

    result = {"count": len(rows), "indicators": rows}
    set_cached(cache_key, result)
    return result


@router.get("/{series_key}")
def get_indicator(
    series_key: str,
    country:    str = Query("US"),
    limit:      int = Query(120, ge=1, le=500),
):
    """Get full time series for a specific indicator."""
    cache_key = f"indicator:{series_key}:{country}:{limit}"
    cached = get_cached(cache_key)
    if cached:
        return cached

    rows = query_all("""
        SELECT
            source, series_key, indicator_name, unit, frequency,
            country_code, date, value, mom_pct, yoy_pct, zscore,
            mom_direction, zscore_label, fetched_at
        FROM public_intermediate.int_indicators_zscore
        WHERE series_key    = :series_key
          AND country_code  = :country
          AND value IS NOT NULL
        ORDER BY date DESC
        LIMIT :limit
    """, {"series_key": series_key.upper(), "country": country.upper(), "limit": limit})

    if not rows:
        from fastapi import HTTPException
        raise HTTPException(status_code=404, detail=f"Indicator '{series_key}' not found")

    result = {
        "series_key":     series_key.upper(),
        "indicator_name": rows[0]["indicator_name"],
        "unit":           rows[0]["unit"],
        "country_code":   country.upper(),
        "count":          len(rows),
        "data":           rows,
    }
    set_cached(cache_key, result)
    return result
EOF

# ── api/routers/countries.py ───────────────────────────────────────────────
cat > api/routers/countries.py << 'EOF'
# Pontic — Countries Router

from fastapi import APIRouter, HTTPException
from api.services.db import query_all, query_one
from api.services.cache import get_cached, set_cached

router = APIRouter(prefix="/countries", tags=["Countries"])


@router.get("/")
def list_countries():
    """List all countries with latest macro snapshot."""
    cache_key = "countries:all"
    cached = get_cached(cache_key)
    if cached:
        return cached

    rows = query_all("""
        SELECT
            country_code, country_name, latest_date,
            gdp_trillions_usd, cpi_inflation_pct, debt_to_gdp_pct,
            unemployment_pct, fdi_inflows_billions_usd, cli_index,
            growth_signal
        FROM public_marts.mart_country_snapshot
        ORDER BY gdp_trillions_usd DESC NULLS LAST
    """)

    result = {"count": len(rows), "countries": rows}
    set_cached(cache_key, result)
    return result


@router.get("/{country_code}")
def get_country(country_code: str):
    """Get full macro snapshot for a specific country."""
    cache_key = f"country:{country_code.upper()}"
    cached = get_cached(cache_key)
    if cached:
        return cached

    row = query_one("""
        SELECT *
        FROM public_marts.mart_country_snapshot
        WHERE country_code = :code
    """, {"code": country_code.upper()})

    if not row:
        raise HTTPException(status_code=404, detail=f"Country '{country_code}' not found")

    set_cached(cache_key, row)
    return row
EOF

# ── api/routers/signals.py ─────────────────────────────────────────────────
cat > api/routers/signals.py << 'EOF'
# Pontic — Market Signals Router

from fastapi import APIRouter, Query
from api.services.db import query_all
from api.services.cache import get_cached, set_cached

router = APIRouter(prefix="/signals", tags=["Signals"])


@router.get("/market")
def market_signals(category: str | None = Query(None)):
    """Get latest market proxy signals with momentum."""
    cache_key = f"signals:market:{category}"
    cached = get_cached(cache_key)
    if cached:
        return cached

    where  = "WHERE 1=1"
    params = {}
    if category:
        where  += " AND category = :category"
        params["category"] = category.lower()

    rows = query_all(f"""
        SELECT
            series_key, ticker, asset_name, category, unit,
            latest_date, latest_price, sma_20, sma_50,
            return_1m_pct, return_3m_pct, above_sma20, trend_signal
        FROM public_marts.mart_market_snapshot
        {where}
        ORDER BY ABS(COALESCE(return_1m_pct, 0)) DESC
    """, params)

    result = {"count": len(rows), "signals": rows}
    set_cached(cache_key, result)
    return result


@router.get("/extremes")
def extreme_signals(threshold: float = Query(1.5, description="Z-score threshold")):
    """Get indicators with extreme z-scores — the most anomalous readings."""
    cache_key = f"signals:extremes:{threshold}"
    cached = get_cached(cache_key)
    if cached:
        return cached

    rows = query_all("""
        SELECT
            source, series_key, indicator_name, country_code,
            latest_date, latest_value, unit,
            mom_pct, yoy_pct, zscore, mom_direction, zscore_label
        FROM public_marts.mart_macro_signals
        WHERE ABS(COALESCE(zscore, 0)) >= :threshold
        ORDER BY ABS(zscore) DESC
    """, {"threshold": threshold})

    result = {"threshold": threshold, "count": len(rows), "extremes": rows}
    set_cached(cache_key, result)
    return result
EOF

# ── api/routers/regime.py ──────────────────────────────────────────────────
cat > api/routers/regime.py << 'EOF'
# Pontic — Macro Regime Router
"""
Classifies the current macro regime based on growth + inflation signals.

Regimes:
  GOLDILOCKS   — Growth up, Inflation down  (best for risk assets)
  REFLATION    — Growth up, Inflation up    (commodities, value)
  STAGFLATION  — Growth down, Inflation up  (worst regime)
  DEFLATION    — Growth down, Inflation down (bonds, defensive)
"""

from fastapi import APIRouter
from api.services.db import query_one, query_all
from api.services.cache import get_cached, set_cached

router = APIRouter(prefix="/regime", tags=["Regime"])


def classify_regime(gdp_yoy: float | None, cpi_yoy: float | None) -> dict:
    """Simple 2x2 regime classification."""
    if gdp_yoy is None or cpi_yoy is None:
        return {"regime": "UNKNOWN", "confidence": "LOW"}

    growth_up    = gdp_yoy  > 0
    inflation_up = cpi_yoy  > 2.5  # Fed target as threshold

    if growth_up and not inflation_up:
        regime = "GOLDILOCKS"
        desc   = "Growth expanding, inflation contained. Historically favourable for equities."
    elif growth_up and inflation_up:
        regime = "REFLATION"
        desc   = "Growth expanding but inflation elevated. Commodities, value stocks, and TIPS tend to outperform."
    elif not growth_up and inflation_up:
        regime = "STAGFLATION"
        desc   = "Growth slowing with elevated inflation. Most challenging macro environment."
    else:
        regime = "DEFLATION"
        desc   = "Growth and inflation both declining. Bonds and defensive assets typically outperform."

    return {
        "regime":      regime,
        "description": desc,
        "gdp_yoy_pct": gdp_yoy,
        "cpi_yoy_pct": cpi_yoy,
        "growth_up":   growth_up,
        "inflation_up": inflation_up,
    }


@router.get("/current")
def current_regime():
    """Get the current macro regime classification for the US."""
    cache_key = "regime:current"
    cached = get_cached(cache_key)
    if cached:
        return cached

    # Pull latest GDP and CPI signals
    gdp = query_one("""
        SELECT yoy_pct FROM public_marts.mart_macro_signals
        WHERE series_key = 'GDP' AND country_code = 'US'
    """)
    cpi = query_one("""
        SELECT yoy_pct FROM public_marts.mart_macro_signals
        WHERE series_key = 'CPI' AND country_code = 'US'
    """)

    gdp_yoy = gdp["yoy_pct"] if gdp else None
    cpi_yoy = cpi["yoy_pct"] if cpi else None

    regime = classify_regime(gdp_yoy, cpi_yoy)

    # Add supporting signals
    signals = query_all("""
        SELECT series_key, indicator_name, latest_value, unit,
               mom_pct, yoy_pct, zscore, zscore_label
        FROM public_marts.mart_macro_signals
        WHERE series_key IN ('GDP','CPI','FED_FUNDS','UNEMPLOYMENT','TREASURY_10Y')
          AND country_code = 'US'
        ORDER BY series_key
    """)

    result = {**regime, "supporting_signals": signals}
    set_cached(cache_key, result)
    return result
EOF

# ── api/main.py ────────────────────────────────────────────────────────────
cat > api/main.py << 'EOF'
# Pontic — FastAPI Application

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from api.routers import indicators, countries, signals, regime

app = FastAPI(
    title="Pontic — Global Macro Intelligence API",
    description="Real-time macro economic data, signals, and regime classification.",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000", "http://localhost:3001"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Routers ────────────────────────────────────────────────────────────────
app.include_router(indicators.router)
app.include_router(countries.router)
app.include_router(signals.router)
app.include_router(regime.router)


@app.get("/", tags=["Health"])
def health():
    return {
        "status":  "ok",
        "service": "Pontic Macro Intelligence API",
        "version": "1.0.0",
        "docs":    "/docs",
    }


@app.get("/ping", tags=["Health"])
def ping():
    return {"ping": "pong"}
EOF

echo "✅ API files written"
