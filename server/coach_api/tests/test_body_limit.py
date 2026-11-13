"""256 KB request body guard."""

from __future__ import annotations

import json

from app.main import MAX_BODY_BYTES
from fastapi.testclient import TestClient


def test_oversize_body_is_rejected(client: TestClient) -> None:
    oversized = b'{"padding":"' + b"a" * (MAX_BODY_BYTES + 100) + b'"}'
    response = client.post(
        "/v1/coach/plan",
        content=oversized,
        headers={"content-type": "application/json"},
    )
    assert response.status_code == 413
    assert response.json()["detail"]["code"] == "payload_too_large"
    assert response.headers.get("X-Request-ID")


def test_body_at_limit_is_not_rejected_by_size_guard(client: TestClient) -> None:
    body = b" " * MAX_BODY_BYTES
    response = client.post(
        "/v1/coach/plan",
        content=body,
        headers={"content-type": "application/json"},
    )
    # Parsed as invalid JSON, not rejected by the size middleware.
    assert response.status_code == 400
    assert response.json()["detail"]["code"] == "invalid_request"


def test_small_body_reaches_validation(client: TestClient) -> None:
    response = client.post(
        "/v1/coach/plan",
        content=json.dumps({"contractVersion": 1}).encode(),
        headers={"content-type": "application/json"},
    )
    assert response.status_code == 400
    assert response.json()["detail"]["code"] == "invalid_request"
