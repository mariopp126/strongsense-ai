"""Optional plan cache for the coach service.

The service remains stateless by default. When ``DATABASE_URL`` is configured
(and ``asyncpg`` is installed) responses are cached in PostgreSQL so identical
requests do not re-trigger an LLM call. Without a database URL an in-memory
cache is used, which keeps tests deterministic and offline-friendly.

Entries expire after ``CACHE_TTL_SECONDS`` (default 86400 seconds; 0 disables
expiry). Transient ``rules_fallback`` responses are never cached by the coach
route, so a temporary provider failure is not pinned forever.
"""

from __future__ import annotations

import datetime
import hashlib
import json
import time
from contextlib import suppress
from typing import Any, Protocol

try:  # optional dependency
    import asyncpg
except Exception:  # pragma: no cover - exercised only when asyncpg missing
    asyncpg = None


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


def _deep_copy(value: dict[str, Any]) -> dict[str, Any]:
    """Return a JSON round-trip copy so callers can't mutate stored state."""
    return json.loads(json.dumps(value))


class InMemoryPlanCache:
    """Process-local cache (default, no external dependencies)."""

    def __init__(self, max_entries: int = 256, ttl_seconds: int = 86400) -> None:
        self._max_entries = max(1, max_entries)
        self._ttl_seconds = max(0, ttl_seconds)
        # key -> (value, expiry_monotonic_or_None)
        self._store: dict[str, tuple[dict[str, Any], float | None]] = {}

    def _expired(self, expiry: float | None) -> bool:
        if expiry is None:
            return False
        return time.monotonic() >= expiry

    def _expiry(self) -> float | None:
        if self._ttl_seconds <= 0:
            return None
        return time.monotonic() + self._ttl_seconds

    async def get(self, key: str) -> dict[str, Any] | None:
        entry = self._store.get(key)
        if entry is None:
            return None
        value, expiry = entry
        if self._expired(expiry):
            self._store.pop(key, None)
            return None
        return _deep_copy(value)

    async def set(self, key: str, value: dict[str, Any]) -> None:
        if len(self._store) >= self._max_entries:
            # No-expiry entries (expiry None) are treated as newest so they are
            # evicted last.
            oldest = min(
                self._store.items(),
                key=lambda item: item[1][1] if item[1][1] is not None else float("inf"),
            )[0]
            self._store.pop(oldest, None)
        self._store[key] = (_deep_copy(value), self._expiry())

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
            created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            expires_at TIMESTAMPTZ
        )
    """

    def __init__(self, database_url: str, ttl_seconds: int = 86400) -> None:
        self._database_url = database_url
        self._ttl_seconds = max(0, ttl_seconds)
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
            self._pool = await asyncpg.create_pool(
                self._database_url, min_size=1, max_size=5
            )
            async with self._pool.acquire() as conn:
                await conn.execute(self._CREATE_TABLE)
            return self._pool
        except Exception:
            self._pool = None
            return None

    def _expiry(self) -> datetime.datetime | None:
        if self._ttl_seconds <= 0:
            return None
        return datetime.datetime.now(datetime.UTC) + datetime.timedelta(
            seconds=self._ttl_seconds
        )

    async def get(self, key: str) -> dict[str, Any] | None:
        pool = await self._ensure_pool()
        if pool is None:
            return None
        try:
            async with pool.acquire() as conn:
                row = await conn.fetchrow(
                    "SELECT response, expires_at FROM coach_plan_cache WHERE cache_key = $1",
                    key,
                )
            if row is None:
                return None
            expires_at = row["expires_at"]
            if expires_at is not None and expires_at <= datetime.datetime.now(
                datetime.UTC
            ):
                try:
                    async with pool.acquire() as conn:
                        await conn.execute(
                            "DELETE FROM coach_plan_cache WHERE cache_key = $1", key
                        )
                except Exception:
                    pass
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
            expires_at = self._expiry()
            async with pool.acquire() as conn:
                await conn.execute(
                    """
                    INSERT INTO coach_plan_cache (cache_key, response, expires_at)
                    VALUES ($1, $2::jsonb, $3)
                    ON CONFLICT (cache_key) DO UPDATE SET
                        response = EXCLUDED.response,
                        expires_at = EXCLUDED.expires_at,
                        created_at = NOW()
                    """,
                    key,
                    json.dumps(value),
                    expires_at,
                )
                await conn.execute(
                    "DELETE FROM coach_plan_cache "
                    "WHERE expires_at IS NOT NULL AND expires_at < NOW()"
                )
        except Exception:
            return None

    async def close(self) -> None:
        if self._pool is not None:
            with suppress(Exception):
                await self._pool.close()
            self._pool = None


def build_cache(settings: Any) -> PlanCache:
    """Build the cache implementation selected by ``settings``."""
    database_url = ""
    try:
        database_url = (getattr(settings, "database_url", "") or "").strip()
    except Exception:
        database_url = ""
    ttl_seconds = 86400
    try:
        ttl_seconds = int(getattr(settings, "cache_ttl_seconds", 86400) or 86400)
    except Exception:
        ttl_seconds = 86400
    if database_url:
        return PostgresPlanCache(database_url, ttl_seconds=ttl_seconds)
    return InMemoryPlanCache(ttl_seconds=ttl_seconds)
