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
