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
