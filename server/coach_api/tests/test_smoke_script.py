"""Tests for the stdlib smoke script's AI-path visibility.

The script itself only uses the standard library, so these tests import it by path
and replace ``request_json``/``check_health`` with fakes.
"""

from __future__ import annotations

import importlib.util
from pathlib import Path
from types import ModuleType
from typing import Any

REPO_ROOT = Path(__file__).resolve().parents[3]
SCRIPT_PATH = REPO_ROOT / "scripts" / "smoke_coach.py"


def _load_script() -> ModuleType:
    spec = importlib.util.spec_from_file_location("smoke_coach", SCRIPT_PATH)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def _fallback_response() -> dict[str, Any]:
    return {
        "contractVersion": 1,
        "source": "rules_fallback",
        "plan": {
            "source": "rules_fallback",
            "summary": "Offline plan",
            "disclaimer": "StrongSense AI provides general training guidance, not medical advice.",
            "deload": False,
            "adjustments": [],
            "tips": [],
            "flags": [],
        },
        "meta": {"provider": "test", "model": "test", "latencyMs": 1},
    }


def _patch(monkeypatch: Any, script: ModuleType) -> None:
    monkeypatch.setattr(script, "check_health", lambda *args, **kwargs: (True, {"status": "ok"}))
    monkeypatch.setattr(
        script,
        "request_json",
        lambda *args, **kwargs: (200, _fallback_response()),
    )


def test_rules_fallback_fails_by_default(monkeypatch: Any) -> None:
    script = _load_script()
    _patch(monkeypatch, script)

    assert script.main(["--base-url", "http://coach.test"]) == 1


def test_rules_fallback_can_be_allowed(monkeypatch: Any) -> None:
    script = _load_script()
    _patch(monkeypatch, script)

    assert script.main(["--base-url", "http://coach.test", "--allow-fallback"]) == 0
