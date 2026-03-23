# Pontic — FastAPI Dependencies

from api.config import get_settings, Settings
from fastapi import Depends

def get_config() -> Settings:
    return get_settings()
