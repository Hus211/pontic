#!/bin/bash
# Writes all Pontic config files

# ── .gitignore ─────────────────────────────────────────────────────────────
cat > .gitignore << 'EOF'
# Python
.venv/
__pycache__/
*.pyc
*.pyo
.pytest_cache/

# Environment
.env

# dbt
warehouse/target/
warehouse/dbt_packages/
warehouse/logs/

# Node
frontend/node_modules/
frontend/.next/

# Data
*.duckdb
*.parquet

# OS
.DS_Store
EOF

# ── .env.example ──────────────────────────────────────────────────────────
cat > .env.example << 'EOF'
# ── Database ───────────────────────────────────────────
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
POSTGRES_DB=pontic
POSTGRES_USER=pontic
POSTGRES_PASSWORD=pontic_dev

# ── Redis ──────────────────────────────────────────────
REDIS_URL=redis://localhost:6379

# ── API Keys (all free) ────────────────────────────────
FRED_API_KEY=your_fred_api_key_here
# World Bank, OECD, ECB, BLS — no key required

# ── App ────────────────────────────────────────────────
API_ENV=development
API_PORT=8000
CACHE_TTL_SECONDS=180
REFRESH_INTERVAL_MINUTES=3
EOF

# ── docker-compose.yml ─────────────────────────────────────────────────────
cat > docker-compose.yml << 'EOF'
version: "3.9"

services:
  postgres:
    image: timescale/timescaledb:latest-pg16
    container_name: pontic_postgres
    environment:
      POSTGRES_DB: pontic
      POSTGRES_USER: pontic
      POSTGRES_PASSWORD: pontic_dev
    ports:
      - "5432:5432"
    volumes:
      - pontic_pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U pontic"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    container_name: pontic_redis
    ports:
      - "6379:6379"
    volumes:
      - pontic_redisdata:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  pontic_pgdata:
  pontic_redisdata:
EOF

# ── requirements.txt ───────────────────────────────────────────────────────
cat > requirements.txt << 'EOF'
# API
fastapi>=0.115
uvicorn[standard]>=0.29
pydantic>=2.0
pydantic-settings>=2.0

# Database
asyncpg>=0.29
sqlalchemy[asyncio]>=2.0
alembic>=1.13

# Cache
redis[hiredis]>=5.0

# Data ingestion
httpx>=0.27
pandas>=2.0
numpy>=1.26
yfinance>=0.2

# Pipeline orchestration
prefect>=3.0

# dbt
dbt-postgres>=1.7

# Utils
python-dotenv>=1.0
tenacity>=8.0        # retry logic for API calls
structlog>=24.0      # structured logging

# Dev
pytest>=8.0
pytest-asyncio>=0.23
httpx                # for API testing
EOF

# ── warehouse/dbt_project.yml ──────────────────────────────────────────────
cat > warehouse/dbt_project.yml << 'EOF'
name: pontic
version: "1.0.0"
config-version: 2

profile: pontic

model-paths: ["models"]
seed-paths: ["seeds"]
test-paths: ["tests"]
macro-paths: ["macros"]
target-path: "target"
clean-targets: ["target", "dbt_packages"]

models:
  pontic:
    staging:
      +materialized: view
      +schema: staging
    intermediate:
      +materialized: view
      +schema: intermediate
    marts:
      +materialized: table
      +schema: marts
EOF

# ── warehouse/profiles.yml ─────────────────────────────────────────────────
cat > warehouse/profiles.yml << 'EOF'
pontic:
  target: dev
  outputs:
    dev:
      type: postgres
      host: localhost
      port: 5432
      dbname: pontic
      user: pontic
      password: pontic_dev
      schema: public
      threads: 4
EOF

# ── README.md ──────────────────────────────────────────────────────────────
cat > README.md << 'EOF'
# Pontic — Global Macro Intelligence Platform

End-to-end macro data platform: ingest → warehouse → transform → API → dashboard.

## Stack
- **Ingestion:** Python + httpx (async) | FRED, World Bank, OECD, BLS, ECB, yfinance
- **Warehouse:** PostgreSQL + TimescaleDB + dbt
- **Cache:** Redis
- **API:** FastAPI
- **Frontend:** Next.js 14 + Tailwind + Tremor + D3.js
- **Orchestration:** Prefect

## Quick Start

```bash
# 1. Start databases
docker compose up -d

# 2. Create virtual environment
python3.11 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

# 3. Copy env file
cp .env.example .env
# Add your FRED API key to .env

# 4. Run dbt
cd warehouse && dbt run

# 5. Start API
uvicorn api.main:app --reload

# 6. Start frontend
cd frontend && npm run dev
```

## Layers
- [ ] Layer 1 — Data ingestion (6 sources)
- [ ] Layer 2 — Warehouse schema + dbt transforms
- [ ] Layer 3 — Regime classifier + derived signals
- [ ] Layer 4 — FastAPI + Redis
- [ ] Layer 5 — Next.js dashboard
- [ ] Layer 6 — Country cards + correlation explorer
- [ ] Layer 7 — Narrative feed + deploy
EOF

echo "✅ Config files written"
