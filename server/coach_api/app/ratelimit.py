"""In-memory token-bucket rate limiting, keyed by client IP (and bearer token).

The service is stateless on disk and is expected to run as a single uvicorn worker;
this limiter is intentionally process-local. A ``threading.Lock`` makes it safe
enough for uvicorn's threadpool and the single event loop.

A limit of 0 (or a negative value) disables rate limiting.
"""

from __future__ import annotations

import math
import threading
import time
from collections.abc import Callable
from dataclasses import dataclass


@dataclass
class _Bucket:
    tokens: float
    updated_at: float


class RateLimiter:
    """Fixed-capacity token bucket per key, refilled continuously per minute."""

    def __init__(
        self,
        limit_per_minute: int,
        *,
        clock: Callable[[], float] = time.monotonic,
    ) -> None:
        self.limit_per_minute = max(0, int(limit_per_minute))
        self._clock = clock
        self._buckets: dict[str, _Bucket] = {}
        self._lock = threading.Lock()

    @property
    def enabled(self) -> bool:
        return self.limit_per_minute > 0

    def allow(self, key: str) -> tuple[bool, float]:
        """Consume one token for ``key``.

        Returns ``(allowed, retry_after_seconds)``. ``retry_after`` is 0 when the
        request is allowed.
        """
        if not self.enabled:
            return True, 0.0
        now = self._clock()
        refill_per_second = self.limit_per_minute / 60.0
        with self._lock:
            bucket = self._buckets.get(key)
            if bucket is None:
                bucket = _Bucket(tokens=float(self.limit_per_minute), updated_at=now)
                self._buckets[key] = bucket
                self._maybe_prune(now)
            else:
                elapsed = max(0.0, now - bucket.updated_at)
                bucket.tokens = min(
                    float(self.limit_per_minute),
                    bucket.tokens + elapsed * refill_per_second,
                )
                bucket.updated_at = now
            if bucket.tokens >= 1.0:
                bucket.tokens -= 1.0
                return True, 0.0
            missing = 1.0 - bucket.tokens
            return False, math.ceil(missing / refill_per_second * 1000.0) / 1000.0

    def reset(self) -> None:
        """Drop all buckets (used by tests)."""
        with self._lock:
            self._buckets.clear()

    def bucket_count(self) -> int:
        with self._lock:
            return len(self._buckets)

    def _maybe_prune(self, now: float) -> None:
        # Bound memory for long-lived processes: drop buckets empty for 5 minutes.
        if len(self._buckets) <= 4096:
            return
        stale_after = 300.0
        for key in [
            key
            for key, bucket in self._buckets.items()
            if now - bucket.updated_at > stale_after
        ]:
            del self._buckets[key]


class RateLimitExceeded(Exception):
    """Raised by the ASGI middleware internals; handled in place."""

    def __init__(self, retry_after_seconds: float) -> None:
        super().__init__("rate limit exceeded")
        self.retry_after_seconds = retry_after_seconds
