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
