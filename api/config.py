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
