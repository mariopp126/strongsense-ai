"""Request validation and contract-version handling."""

from __future__ import annotations

import json
from typing import Any

import pytest
from app.schemas import CONTRACT_VERSION
from fastapi.testclient import TestClient


def _post(client: TestClient, payload: Any) -> Any:
    return client.post("/v1/coach/plan", json=payload)


def test_valid_request_passes_validation(client: TestClient, plan_payload: dict[str, Any]) -> None:
    payload = json.loads(json.dumps(plan_payload))
    payload["forceRules"] = True
    assert _post(client, payload).status_code == 200


@pytest.mark.parametrize(
    "mutation",
    [
        lambda payload: payload.pop("context"),
        lambda payload: payload.pop("contractVersion"),
        lambda payload: payload["context"].update({"blockWeek": 53}),
        lambda payload: payload["context"].update({"blockWeek": 0}),
        lambda payload: payload["context"].update({"unit": "stone"}),
        lambda payload: payload["context"]["checkIn"].update({"sleepQuality": 6}),
        lambda payload: payload["context"]["checkIn"].update({"painSeverity": 11}),
        lambda payload: payload["context"]["checkIn"].update({"timeAvailableMin": 5}),
        lambda payload: payload["context"]["readiness"].update({"band": "purple"}),
        lambda payload: payload["context"]["readiness"].update({"score": 101}),
        lambda payload: payload["context"]["readiness"]["components"].update({"sleep": -1}),
        lambda payload: payload["context"]["programDay"]["exercises"][0].update({"role": "warmup"}),
        lambda payload: payload["context"]["programDay"]["exercises"][0]["setTargets"][0].update(
            {"reps": 0}
        ),
        lambda payload: payload["context"]["programDay"]["exercises"][0]["setTargets"][0].update(
            {"reps": 10, "repsMax": 5}
        ),
        lambda payload: payload["context"]["programDay"]["exercises"][0]["setTargets"][0].update(
            {"loadKg": -5}
        ),
        lambda payload: payload["context"]["programDay"]["exercises"][0].update({"unknown": 1}),
        lambda payload: payload["context"]["constraints"].update({"maxTips": 99}),
        lambda payload: payload["context"].update(
            {"recentSessions": payload["context"]["recentSessions"] * 3}
        ),
        lambda payload: payload["context"].pop("constraints"),
        lambda payload: payload["context"].pop("checkIn"),
    ],
)
def test_invalid_payloads_return_400(
    client: TestClient,
    plan_payload: dict[str, Any],
    mutation: Any,
) -> None:
    payload = json.loads(json.dumps(plan_payload))
    mutation(payload)
    response = _post(client, payload)
    assert response.status_code == 400, response.text
    assert response.json()["detail"]["code"] == "invalid_request"
    assert response.json()["detail"]["message"]


def test_extra_top_level_field_rejected(client: TestClient, plan_payload: dict[str, Any]) -> None:
    payload = json.loads(json.dumps(plan_payload))
    payload["extraField"] = True
    response = _post(client, payload)
    assert response.status_code == 400
    assert response.json()["detail"]["code"] == "invalid_request"


def test_out_of_range_baseline_plan_rejected(
    client: TestClient,
    plan_payload: dict[str, Any],
) -> None:
    payload = json.loads(json.dumps(plan_payload))
    payload["baselinePlan"]["adjustments"][0]["loadDeltaPct"] = 25.0
    response = _post(client, payload)
    assert response.status_code == 400


def test_baseline_plan_deload_mismatch_rejected(
    client: TestClient,
    plan_payload: dict[str, Any],
) -> None:
    payload = json.loads(json.dumps(plan_payload))
    payload["baselinePlan"]["deload"] = True
    payload["baselinePlan"]["adjustments"][0]["loadDeltaPct"] = 1.0  # positive in a deload
    response = _post(client, payload)
    assert response.status_code == 400


def test_malformed_json_returns_400(client: TestClient) -> None:
    response = client.post(
        "/v1/coach/plan",
        content=b'{"contractVersion": 1,',
        headers={"content-type": "application/json"},
    )
    assert response.status_code == 400
    assert response.json()["detail"]["code"] == "invalid_request"


def test_non_json_content_type_returns_400(client: TestClient) -> None:
    response = client.post(
        "/v1/coach/plan",
        content=b"hello",
        headers={"content-type": "text/plain"},
    )
    assert response.status_code == 400
    assert response.json()["detail"]["code"] == "invalid_request"


@pytest.mark.parametrize("version", [0, 2, 99])
def test_unsupported_contract_version_returns_409(
    client: TestClient,
    plan_payload: dict[str, Any],
    version: int,
) -> None:
    payload = json.loads(json.dumps(plan_payload))
    payload["contractVersion"] = version
    response = _post(client, payload)
    assert response.status_code == 409
    assert response.json()["detail"]["code"] == "contract_version_unsupported"


def test_supported_contract_version(client: TestClient, plan_payload: dict[str, Any]) -> None:
    payload = json.loads(json.dumps(plan_payload))
    payload["contractVersion"] = CONTRACT_VERSION
    payload["forceRules"] = True
    assert _post(client, payload).status_code == 200


def test_force_rules_without_baseline_returns_400(
    client: TestClient,
    plan_payload: dict[str, Any],
) -> None:
    payload = json.loads(json.dumps(plan_payload))
    payload.pop("baselinePlan")
    payload["forceRules"] = True
    response = _post(client, payload)
    assert response.status_code == 400
    assert response.json()["detail"]["code"] == "invalid_request"


def test_locale_defaults_to_english(
    client: TestClient,
    request_example: dict[str, Any],
) -> None:
    from app.schemas import CoachRequest

    payload = json.loads(json.dumps(request_example))
    payload.pop("locale")
    request = CoachRequest.model_validate(payload)
    assert request.locale == "en"
