#!/bin/bash
# Pontic — Full Project Scaffold
# Run from inside your empty Pontic folder

set -e

echo "🏗  Scaffolding Pontic..."

# ── Root config files ──────────────────────────────────────────────────────
touch .env .env.example .gitignore README.md docker-compose.yml

# ── Ingestion layer ────────────────────────────────────────────────────────
mkdir -p ingestion/{sources,tests}
touch ingestion/__init__.py
touch ingestion/sources/__init__.py
touch ingestion/sources/fred.py
touch ingestion/sources/worldbank.py
touch ingestion/sources/oecd.py
touch ingestion/sources/bls.py
touch ingestion/sources/ecb.py
touch ingestion/sources/yfinance.py
touch ingestion/tests/__init__.py

# ── Pipeline / orchestration ───────────────────────────────────────────────
mkdir -p pipeline
touch pipeline/__init__.py
touch pipeline/flows.py
touch pipeline/schedules.py

# ── Warehouse / dbt ────────────────────────────────────────────────────────
mkdir -p warehouse/{models/{staging,marts,intermediate},seeds,tests,macros}
touch warehouse/dbt_project.yml
touch warehouse/profiles.yml
touch warehouse/models/staging/.gitkeep
touch warehouse/models/intermediate/.gitkeep
touch warehouse/models/marts/.gitkeep

# ── Backend API ────────────────────────────────────────────────────────────
mkdir -p api/{routers,services,tests}
touch api/__init__.py
touch api/main.py
touch api/config.py
touch api/dependencies.py
touch api/routers/__init__.py
touch api/routers/indicators.py
touch api/routers/countries.py
touch api/routers/regime.py
touch api/routers/signals.py
touch api/services/__init__.py
touch api/services/cache.py
touch api/services/db.py
touch api/tests/__init__.py

# ── Frontend ───────────────────────────────────────────────────────────────
mkdir -p frontend

# ── Tests ─────────────────────────────────────────────────────────────────
mkdir -p tests
touch tests/__init__.py

# ── Python env ────────────────────────────────────────────────────────────
touch requirements.txt

echo "✅ Scaffold complete"
