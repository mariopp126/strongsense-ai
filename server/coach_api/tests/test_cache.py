"""Tests for the optional plan cache (app/cache.py).

No test touches a real database: ``PostgresPlanCache`` is exercised with a fake
connection/pool, and the coach route's ``rules_fallback`` guard is tested by
stubbing ``generate_plan``.
"""

from __future__ import annotations

import hashlib
import time
from datetime import UTC, datetime, timedelta
from typing import Any

import pytest
from app.cache import (
    InMemoryPlanCache,
    NullPlanCache,
    PostgresPlanCache,
    build_cache,
    cache_key_for,
)
from app.config import Settings
from app.main import create_app
from app.schemas import (
    CoachPlan,
    CoachResponse,
    Meta,
    PlanSource,
)
from fastapi.testclient import TestClient

# ---------------------------------------------------------------------------
# Fake database primitives for PostgresPlanCache (no real DB required)
# ---------------------------------------------------------------------------


class _Row:
    def __init__(self, response: str, expires_at: datetime | None) -> None:
        self._response = response
        self._expires_at = expires_at

    def __getitem__(self, item: str) -> Any:
        if item == "response":
            return self._response
        if item == "expires_at":
            return self._expires_at
        raise KeyError(item)


class FakeConn:
    """In-memory stand-in for an asyncpg connection."""

    def __init__(self) -> None:
        self.rows: dict[str, tuple[str, datetime | None]] = {}
        self.deleted: list[str] = []

    async def __aenter__(self) -> FakeConn:
        return self

    async def __aexit__(self, *args: Any) -> bool:
        return False

    async def fetchrow(self, query: str, key: str) -> Any:
        entry = self.rows.get(key)
        if entry is None:
            return None
        response, expires_at = entry
        return _Row(response=response, expires_at=expires_at)

    async def execute(self, query: str, *args: Any) -> None:
        q = " ".join(query.split())
        if "ON CONFLICT" in q:
            key = args[0]
            response = args[1]
            expires_at = args[2] if len(args) > 2 else None
            self.rows[key] = (response, expires_at)
        elif "WHERE cache_key = $1" in q:
            self.deleted.append(args[0])
            self.rows.pop(args[0], None)
        elif "expires_at < NOW()" in q:
            now = datetime.now(UTC)
            for key in list(self.rows):
                _, expires_at = self.rows[key]
                if expires_at is not None and expires_at < now:
                    self.deleted.append(key)
                    self.rows.pop(key, None)


class FakePool:
    def __init__(self, conn: FakeConn) -> None:
        self._conn = conn
        self.closed = False

    def acquire(self) -> FakeConn:
        return self._conn

    async def close(self) -> None:
        self.closed = True


def _use_fake_pool(
    monkeypatch: pytest.MonkeyPatch, cache: PostgresPlanCache, pool: FakePool
) -> None:
    async def fake_ensure(self: Any) -> Any:
        self._pool = pool
        return pool

    monkeypatch.setattr(PostgresPlanCache, "_ensure_pool", fake_ensure)


# ---------------------------------------------------------------------------
# cache_key_for
# ---------------------------------------------------------------------------


def test_cache_key_for_is_deterministic() -> None:
    payload = {"contractVersion": 1, "locale": "en"}
    assert cache_key_for(payload) == cache_key_for(payload)


def test_cache_key_for_differs_for_different_payloads() -> None:
    assert cache_key_for({"a": 1}) != cache_key_for({"a": 2})


def test_cache_key_for_is_key_order_independent() -> None:
    assert cache_key_for({"a": 1, "b": 2}) == cache_key_for({"b": 2, "a": 1})


def test_cache_key_for_handles_non_serializable() -> None:
    key = cache_key_for(object())
    assert isinstance(key, str) and len(key) == 64


def test_cache_key_for_falls_back_to_repr(monkeypatch: pytest.MonkeyPatch) -> None:
    import app.cache as cache_module

    real_dumps = cache_module.json.dumps

    def _raising(*args: Any, **kwargs: Any) -> Any:
        raise TypeError("not serializable")

    monkeypatch.setattr(cache_module.json, "dumps", _raising)
    try:
        key = cache_key_for({"a": 1})
    finally:
        cache_module.json.dumps = real_dumps
    assert key == hashlib.sha256(repr({"a": 1}).encode("utf-8")).hexdigest()


# ---------------------------------------------------------------------------
# InMemoryPlanCache
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_in_memory_cache_round_trip_returns_copy() -> None:
    cache = InMemoryPlanCache()
    await cache.set("k1", {"nested": {"value": 1}})
    got = await cache.get("k1")
    assert got == {"nested": {"value": 1}}
    got["nested"]["value"] = 999
    assert (await cache.get("k1"))["nested"]["value"] == 1


@pytest.mark.asyncio
async def test_in_memory_cache_miss_returns_none() -> None:
    cache = InMemoryPlanCache()
    assert await cache.get("missing") is None


@pytest.mark.asyncio
async def test_in_memory_cache_overwrite() -> None:
    cache = InMemoryPlanCache()
    await cache.set("k1", {"v": 1})
    await cache.set("k1", {"v": 2})
    assert (await cache.get("k1"))["v"] == 2


@pytest.mark.asyncio
async def test_in_memory_cache_evicts_oldest_when_full() -> None:
    cache = InMemoryPlanCache(max_entries=2, ttl_seconds=0)
    await cache.set("a", {"v": 1})
    await cache.set("b", {"v": 2})
    await cache.set("c", {"v": 3})
    assert await cache.get("a") is None
    assert await cache.get("b") == {"v": 2}
    assert await cache.get("c") == {"v": 3}


@pytest.mark.asyncio
async def test_in_memory_cache_ttl_expires(monkeypatch: pytest.MonkeyPatch) -> None:
    cache = InMemoryPlanCache(ttl_seconds=60)
    await cache.set("k1", {"v": 1})
    assert await cache.get("k1") == {"v": 1}
    real_monotonic = time.monotonic
    monkeypatch.setattr(time, "monotonic", lambda: real_monotonic() + 120)
    assert await cache.get("k1") is None
    assert await cache.get("k1") is None  # expired entry was evicted on read


@pytest.mark.asyncio
async def test_in_memory_cache_ttl_disabled(monkeypatch: pytest.MonkeyPatch) -> None:
    cache = InMemoryPlanCache(ttl_seconds=0)
    await cache.set("k1", {"v": 1})
    real_monotonic = time.monotonic
    monkeypatch.setattr(time, "monotonic", lambda: real_monotonic() + 100000)
    assert (await cache.get("k1"))["v"] == 1


@pytest.mark.asyncio
async def test_in_memory_cache_close_clears() -> None:
    cache = InMemoryPlanCache()
    await cache.set("k1", {"v": 1})
    await cache.close()
    assert await cache.get("k1") is None


# ---------------------------------------------------------------------------
# NullPlanCache
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_null_cache_is_noop() -> None:
    cache = NullPlanCache()
    assert await cache.get("anything") is None
    await cache.set("anything", {"v": 1})
    assert await cache.get("anything") is None
    await cache.close()


# ---------------------------------------------------------------------------
# PostgresPlanCache (fake pool, no real DB)
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_postgres_cache_round_trip(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    conn = FakeConn()
    pool = FakePool(conn)
    cache = PostgresPlanCache("postgres://user:pass@localhost:5432/db", ttl_seconds=60)
    _use_fake_pool(monkeypatch, cache, pool)

    assert await cache.get("missing") is None
    await cache.set("k1", {"v": 1})
    assert (await cache.get("k1"))["v"] == 1
    # Second lookup reuses the existing pool.
    assert (await cache.get("k1"))["v"] == 1
    await cache.set("k1", {"v": 2})
    assert (await cache.get("k1"))["v"] == 2
    assert not pool.closed
    await cache.close()
    assert pool.closed


@pytest.mark.asyncio
async def test_postgres_cache_ignores_expired_rows(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    conn = FakeConn()
    pool = FakePool(conn)
    cache = PostgresPlanCache("postgres://localhost/db", ttl_seconds=60)
    _use_fake_pool(monkeypatch, cache, pool)

    # Insert an already-expired row directly into the fake store.
    expired = datetime.now(UTC) - timedelta(seconds=10)
    conn.rows["stale"] = ('{"v": 1}', expired)
    assert await cache.get("stale") is None
    assert "stale" in conn.deleted

    # A fresh row is returned normally.
    fresh = datetime.now(UTC) + timedelta(seconds=60)
    conn.rows["fresh"] = ('{"v": 2}', fresh)
    assert (await cache.get("fresh"))["v"] == 2


@pytest.mark.asyncio
async def test_postgres_cache_no_ttl_when_ttl_zero(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    conn = FakeConn()
    pool = FakePool(conn)
    cache = PostgresPlanCache("postgres://localhost/db", ttl_seconds=0)
    _use_fake_pool(monkeypatch, cache, pool)

    await cache.set("k1", {"v": 1})
    _, expires_at = conn.rows["k1"]
    assert expires_at is None
    assert (await cache.get("k1"))["v"] == 1


@pytest.mark.asyncio
async def test_postgres_cache_returns_none_when_asyncpg_missing(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    import app.cache as cache_module

    monkeypatch.setattr(cache_module, "asyncpg", None)
    cache = PostgresPlanCache("postgres://localhost/db")
    assert await cache.get("k1") is None
    await cache.set("k1", {"v": 1})
    await cache.close()


# ---------------------------------------------------------------------------
# build_cache
# ---------------------------------------------------------------------------


def test_build_cache_defaults_to_in_memory() -> None:
    settings = Settings(_env_file=None, database_url="", app_env="test")
    cache = build_cache(settings)
    assert isinstance(cache, InMemoryPlanCache)


def test_build_cache_uses_postgres_when_database_url_set() -> None:
    settings = Settings(
        _env_file=None,
        database_url="postgresql://user:pass@localhost:5432/strongsense",
        app_env="test",
    )
    cache = build_cache(settings)
    assert isinstance(cache, PostgresPlanCache)


def test_build_cache_passes_ttl_to_in_memory(monkeypatch: pytest.MonkeyPatch) -> None:
    settings = Settings(_env_file=None, database_url="", cache_ttl_seconds=123, app_env="test")
    cache = build_cache(settings)
    assert isinstance(cache, InMemoryPlanCache)
    assert cache._ttl_seconds == 123


# ---------------------------------------------------------------------------
# Coach route never caches rules_fallback
# ---------------------------------------------------------------------------


class RecordingCache:
    def __init__(self) -> None:
        self.get_calls: list[str] = []
        self.set_calls: list[tuple[str, dict[str, Any]]] = []
        self._store: dict[str, dict[str, Any]] = {}
        self.closed = False

    async def get(self, key: str) -> dict[str, Any] | None:
        self.get_calls.append(key)
        return self._store.get(key)

    async def set(self, key: str, value: dict[str, Any]) -> None:
        self.set_calls.append((key, value))
        self._store[key] = value

    async def close(self) -> None:
        self.closed = True


def _fallback_response() -> CoachResponse:
    plan = CoachPlan(
        source=PlanSource.RULES_FALLBACK,
        summary="fallback",
        readinessExplanation="provider down",
        rpeCap=7.0,
        deload=False,
    )
    return CoachResponse(
        contractVersion=1,
        source=PlanSource.RULES_FALLBACK,
        plan=plan,
        meta=Meta(
            provider="unknown",
            model="unknown",
            latencyMs=1,
            clamped=False,
            droppedAdjustments=0,
        ),
    )


def _llm_response() -> CoachResponse:
    plan = CoachPlan(
        source=PlanSource.LLM,
        summary="llm plan",
        readinessExplanation="ok",
        rpeCap=8.0,
        deload=False,
    )
    return CoachResponse(
        contractVersion=1,
        source=PlanSource.LLM,
        plan=plan,
        meta=Meta(
            provider="openai_compatible",
            model="test-model",
            latencyMs=10,
            clamped=False,
            droppedAdjustments=0,
        ),
    )


async def _fake_generate(payload: Any, settings: Any, diagnostics: Any) -> CoachResponse:
    return _fallback_response()


async def _fake_generate_llm(payload: Any, settings: Any, diagnostics: Any) -> CoachResponse:
    return _llm_response()


def test_rules_fallback_is_not_cached(
    monkeypatch: pytest.MonkeyPatch,
    plan_payload: dict[str, Any],
) -> None:
    settings = Settings(
        _env_file=None,
        app_env="test",
        database_url="postgresql://user:pass@localhost:5432/db",
        llm_provider="openai_compatible",
        llm_base_url="https://llm.test/v1",
        llm_model="test-model",
        llm_api_key="sk-test-key",
    )
    recording = RecordingCache()
    app = create_app(settings)
    app.state.cache = recording

    monkeypatch.setattr("app.main.generate_plan", _fake_generate)

    with TestClient(app) as client:
        response = client.post("/v1/coach/plan", json=plan_payload)

    assert response.status_code == 200
    assert response.json()["source"] == "rules_fallback"
    assert recording.set_calls == []
    assert recording.closed


def test_llm_plan_is_cached(
    monkeypatch: pytest.MonkeyPatch,
    plan_payload: dict[str, Any],
) -> None:
    settings = Settings(
        _env_file=None,
        app_env="test",
        database_url="",
        llm_provider="openai_compatible",
        llm_base_url="https://llm.test/v1",
        llm_model="test-model",
        llm_api_key="sk-test-key",
    )
    recording = RecordingCache()
    app = create_app(settings)
    app.state.cache = recording

    monkeypatch.setattr("app.main.generate_plan", _fake_generate_llm)

    with TestClient(app) as client:
        first = client.post("/v1/coach/plan", json=plan_payload)
        second = client.post("/v1/coach/plan", json=plan_payload)

    assert first.status_code == 200
    assert second.status_code == 200
    assert first.json()["source"] == "llm"
    # First response populated the cache; second was served from it (only one set,
    # two cache lookups — one per request).
    assert len(recording.set_calls) == 1
    assert len(recording.get_calls) == 2
