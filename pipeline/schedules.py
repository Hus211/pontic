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