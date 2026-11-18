"""Optional plan cache for the coach service.

The service remains stateless by default. When ``DATABASE_URL`` is configured (and
``asyncpg`` is installed) responses are cached in PostgreSQL so identical
requests do not re-trigger an LLM call. Without a database URL an in-memory
cache is used, which keeps tests deterministic and offline-friendly.
"""

from __future__ import annotations

import hashlib
import json
import time
from typing import Any, Protocol

try:  # optional dependency
    import asyncpg  # type: ignore[import-not-found]
except Exception:  # pragma: no cover - exercised only when asyncpg missing
    asyncpg = None  # type: ignore[assignment]


class PlanCache(Protocol):
    """Minimal async cache contract used by the coach route."""

    async def get(self, key: str) -> dict[str, Any] | None: ...

    async def set(self, key: str, value: dict[str, Any]) -> None: ...

    async def close(self) -> None: ...


def cache_key_for(payload: Any) -> str:
    """Stable hash of a coach request payload."""
    try:
        canonical = json.dumps(payload, sort_keys=True, default=str, separators=(",", ":"))
    except (TypeError, ValueError):
        canonical = repr(payload)
    return hashlib.sha256(canonical.encode("utf-8")).hexdigest()


class InMemoryPlanCache:
    """Process-local cache (default, no external dependencies)."""

    def __init__(self, max_entries: int = 256) -> None:
        self._max_entries = max(1, max_entries)
        self._store: dict[str, tuple[dict[str, Any], float]] = {}

    async def get(self, key: str) -> dict[str, Any] | None:
        entry = self._store.get(key)
        if entry is None:
            return None
        value, _ = entry
        return json.loads(json.dumps(value))

    async def set(self, key: str, value: dict[str, Any]) -> None:
        if len(self._store) >= self._max_entries:
            oldest = min(self._store.items(), key=lambda item: item[1][1])[0]
            self._store.pop(oldest, None)
        self._store[key] = (json.loads(json.dumps(value)), time.monotonic())

    async def close(self) -> None:
        self._store.clear()


class NullPlanCache:
    """No-op cache used when caching is disabled."""

    async def get(self, key: str) -> dict[str, Any] | None:
        return None

    async def set(self, key: str, value: dict[str, Any]) -> None:
        return None

    async def close(self) -> None:
        return None


class PostgresPlanCache:
    """PostgreSQL-backed cache. Requires ``asyncpg`` and a ``DATABASE_URL``."""

    _CREATE_TABLE = """
        CREATE TABLE IF NOT EXISTS coach_plan_cache (
            cache_key TEXT PRIMARY KEY,
            response JSONB NOT NULL,
            created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
        )
    """

    def __init__(self, database_url: str) -> None:
        self._database_url = database_url
        self._pool: Any = None
        self._tried: bool = False

    async def _ensure_pool(self) -> Any:
        if self._pool is not None:
            return self._pool
        if self._tried:
            return None
        self._tried = True
        if asyncpg is None:
            return None
        try:
            self._pool = await asyncpg.create_pool(self._database_url, min_size=1, max_size=5)
            async with self._pool.acquire() as conn:
                await conn.execute(self._CREATE_TABLE)
            return self._pool
        except Exception:
            self._pool = None
            return None

    async def get(self, key: str) -> dict[str, Any] | None:
        pool = await self._ensure_pool()
        if pool is None:
            return None
        try:
            async with pool.acquire() as conn:
                row = await conn.fetchrow(
                    "SELECT response FROM coach_plan_cache WHERE cache_key = $1", key
                )
            if row is None:
                return None
            value = row["response"]
            if isinstance(value, str):
                return json.loads(value)
            return dict(value)
        except Exception:
            return None

    async def set(self, key: str, value: dict[str, Any]) -> None:
        pool = await self._ensure_pool()
        if pool is None:
            return
        try:
            async with pool.acquire() as conn:
                await conn.execute(
                    """
                    INSERT INTO coach_plan_cache (cache_key, response)
                    VALUES ($1, $2::jsonb)
                    ON CONFLICT (cache_key) DO UPDATE SET response = EXCLUDED.response,
                                                          created_at = NOW()
                    """,
                    key,
                    json.dumps(value),
                )
        except Exception:
            return None

    async def close(self) -> None:
        if self._pool is not None:
            try:
                await self._pool.close()
            except Exception:
                pass
            self._pool = None


def build_cache(settings: Any) -> PlanCache:
    """Build the cache implementation selected by ``settings``."""
    database_url = ""
    try:
        database_url = (getattr(settings, "database_url", "") or "").strip()
    except Exception:
        database_url = ""
    if database_url:
        return PostgresPlanCache(database_url)
    return InMemoryPlanCache()
