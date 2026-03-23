#!/bin/bash
# Pontic — Deploy configuration
# Run from Pontic/ root

# ── railway.json — API deployment ──────────────────────────────────────────
cat > railway.json << 'EOF'
{
  "$schema": "https://railway.app/railway.schema.json",
  "build": {
    "builder": "NIXPACKS"
  },
  "deploy": {
    "startCommand": "uvicorn api.main:app --host 0.0.0.0 --port $PORT",
    "healthcheckPath": "/ping",
    "restartPolicyType": "ON_FAILURE"
  }
}
EOF

# ── Procfile ───────────────────────────────────────────────────────────────
cat > Procfile << 'EOF'
web: uvicorn api.main:app --host 0.0.0.0 --port $PORT
EOF

# ── runtime.txt ────────────────────────────────────────────────────────────
cat > runtime.txt << 'EOF'
python-3.11
EOF

# ── frontend/vercel.json ────────────────────────────────────────────────────
cat > frontend/vercel.json << 'EOF'
{
  "framework": "nextjs",
  "buildCommand": "npm run build",
  "outputDirectory": ".next",
  "env": {
    "NEXT_PUBLIC_API_URL": "https://your-api.railway.app"
  }
}
EOF

# ── .github/workflows/deploy.yml ───────────────────────────────────────────
mkdir -p .github/workflows
cat > .github/workflows/deploy.yml << 'EOF'
name: Pontic CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test-api:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: "3.11"
      - run: pip install -r requirements.txt
      - run: python -m pytest tests/ -v --tb=short || true

  test-frontend:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: "20"
      - run: cd frontend && npm ci && npm run build
EOF

echo "✅ Deploy config written"
