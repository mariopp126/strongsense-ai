"""Rate limiting: unit behaviour and HTTP integration."""

from __future__ import annotations

import json
from collections.abc import Callable
from typing import Any

from app.main import _client_rate_limit_key
from app.ratelimit import RateLimiter
from fastapi.testclient import TestClient


def test_limiter_allows_then_denies() -> None:
    now = [0.0]
    limiter = RateLimiter(3, clock=lambda: now[0])
    assert limiter.enabled is True
    assert [limiter.allow("client")[0] for _ in range(3)] == [True, True, True]
    allowed, retry_after = limiter.allow("client")
    assert allowed is False
    assert retry_after > 0.0


def test_limiter_refills_over_time() -> None:
    now = [0.0]
    limiter = RateLimiter(60, clock=lambda: now[0])  # 1 token per second
    for _ in range(60):
        assert limiter.allow("client")[0] is True
    assert limiter.allow("client")[0] is False
    now[0] += 1.0
    assert limiter.allow("client")[0] is True


def test_limiter_is_per_key() -> None:
    limiter = RateLimiter(1)
    assert limiter.allow("a")[0] is True
    assert limiter.allow("a")[0] is False
    assert limiter.allow("b")[0] is True
    assert limiter.bucket_count() == 2


def test_limiter_disabled() -> None:
    limiter = RateLimiter(0)
    assert limiter.enabled is False
    for _ in range(100):
        assert limiter.allow("anything") == (True, 0.0)


def test_limiter_reset() -> None:
    limiter = RateLimiter(1)
    limiter.allow("a")
    assert limiter.allow("a")[0] is False
    limiter.reset()
    assert limiter.bucket_count() == 0
    assert limiter.allow("a")[0] is True


def test_limiter_prunes_stale_buckets() -> None:
    now = [0.0]
    limiter = RateLimiter(10, clock=lambda: now[0])
    for index in range(4097):
        limiter.allow(f"client-{index}")
    now[0] += 1000.0
    limiter.allow("new-client")
    assert limiter.bucket_count() < 4097


def test_client_rate_limit_key() -> None:
    scope: dict[str, Any] = {"client": ("1.2.3.4", 555), "headers": []}
    assert _client_rate_limit_key(scope) == "1.2.3.4"
    scope["headers"] = [(b"authorization", b"Bearer abc")]
    key = _client_rate_limit_key(scope)
    assert key.startswith("1.2.3.4|")
    assert "abc" not in key
    assert _client_rate_limit_key({"headers": []}) == "unknown"


def test_rate_limit_returns_429(
    make_client: Callable[..., TestClient],
    plan_payload: dict[str, Any],
) -> None:
    payload = json.loads(json.dumps(plan_payload))
    payload["forceRules"] = True
    with make_client(max_requests_per_min=2) as client:
        assert client.post("/v1/coach/plan", json=payload).status_code == 200
        assert client.post("/v1/coach/plan", json=payload).status_code == 200
        limited = client.post("/v1/coach/plan", json=payload)
        # Health checks are not rate limited.
        assert client.get("/health").status_code == 200

    assert limited.status_code == 429
    assert limited.json()["detail"]["code"] == "rate_limited"
    assert "Retry-After" in limited.headers
    assert int(limited.headers["Retry-After"]) >= 1
    assert limited.headers.get("X-Request-ID")


def test_rate_limit_cors_header_present_on_429(
    make_client: Callable[..., TestClient],
    plan_payload: dict[str, Any],
) -> None:
    payload = json.loads(json.dumps(plan_payload))
    payload["forceRules"] = True
    origin = "http://localhost:5173"
    with make_client(max_requests_per_min=1) as client:
        first = client.post("/v1/coach/plan", json=payload, headers={"Origin": origin})
        second = client.post("/v1/coach/plan", json=payload, headers={"Origin": origin})
    assert first.status_code == 200
    assert second.status_code == 429
    assert second.headers.get("access-control-allow-origin") == origin
