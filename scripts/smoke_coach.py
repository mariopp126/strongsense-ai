#!/usr/bin/env python3
"""Smoke-test a running StrongSense coach API with the shared contract fixture.

This script intentionally depends on the Python standard library only, so it can be
run from the repository root without the server virtualenv or any third-party package.

Usage (from the repository root):

    python scripts/smoke_coach.py
    python scripts/smoke_coach.py --base-url http://127.0.0.1:8080 --token <bearer>
    python scripts/smoke_coach.py --health-only
    python scripts/smoke_coach.py --force-rules      # exercise the offline path

Exit codes:
    0  the server answered /health and /v1/coach/plan with a contract-shaped plan
    1  an endpoint failed, the payload was malformed, or the response was invalid
    2  the server is healthy but has no AI provider configured (503 llm_not_configured)
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_REQUEST_FILE = REPO_ROOT / "docs" / "contract" / "coach-request.example.json"
DEFAULT_BASE_URL = "http://127.0.0.1:8080"
HEALTH_TIMEOUT_SECONDS = 10.0


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Send docs/contract/coach-request.example.json to a running StrongSense "
            "coach API and validate the response envelope."
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "--base-url",
        default=os.environ.get("COACH_BASE_URL", DEFAULT_BASE_URL),
        help=f"Coach API base URL (default: env COACH_BASE_URL or {DEFAULT_BASE_URL})",
    )
    parser.add_argument(
        "--token",
        default=os.environ.get("COACH_API_TOKEN", ""),
        help="Bearer token (default: env COACH_API_TOKEN, empty disables auth)",
    )
    parser.add_argument(
        "--request-file",
        default=str(DEFAULT_REQUEST_FILE),
        help="Request fixture to send (default: docs/contract/coach-request.example.json)",
    )
    parser.add_argument(
        "--timeout",
        type=float,
        default=30.0,
        help="HTTP timeout in seconds (default: 30)",
    )
    parser.add_argument(
        "--health-only",
        action="store_true",
        help="Only call GET /health and exit",
    )
    parser.add_argument(
        "--force-rules",
        action="store_true",
        help="Set forceRules=true so the server returns the baseline rules plan",
    )
    parser.add_argument(
        "--allow-fallback",
        action="store_true",
        help=(
            "Accept source=rules_fallback (the provider failed). By default the smoke "
            "test fails so a broken provider key/model is visible."
        ),
    )
    parser.add_argument(
        "--print-response",
        action="store_true",
        help="Print the full JSON response body (pretty printed)",
    )
    return parser.parse_args(argv)


def _headers(token: str) -> dict[str, str]:
    headers = {"Accept": "application/json", "Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    return headers


def request_json(
    method: str,
    url: str,
    *,
    payload: dict[str, Any] | None = None,
    token: str = "",
    timeout: float = 30.0,
) -> tuple[int, dict[str, Any]]:
    """Perform one HTTP request and decode the JSON response body."""
    body = json.dumps(payload).encode("utf-8") if payload is not None else None
    request = urllib.request.Request(url, data=body, headers=_headers(token), method=method)
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            raw = response.read()
            return int(response.status), _decode_json(raw)
    except urllib.error.HTTPError as exc:
        raw = exc.read()
        return int(exc.code), _decode_json(raw)
    except urllib.error.URLError as exc:
        raise SystemExit(f"FAIL: cannot reach {url}: {exc.reason}") from exc


def _decode_json(raw: bytes) -> dict[str, Any]:
    if not raw:
        return {}
    try:
        decoded = json.loads(raw.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError):
        return {"_raw": raw.decode("utf-8", errors="replace")[:500]}
    return decoded if isinstance(decoded, dict) else {"_raw": decoded}


def _error_code(payload: dict[str, Any]) -> str:
    detail = payload.get("detail")
    if isinstance(detail, dict):
        return str(detail.get("code", ""))
    return ""


def check_health(base_url: str, timeout: float) -> tuple[bool, dict[str, Any]]:
    status, payload = request_json("GET", f"{base_url.rstrip('/')}/health", timeout=timeout)
    ok = status == 200 and payload.get("status") == "ok"
    print(f"GET  /health            -> {status}")
    print(f"     service={payload.get('service')!r} version={payload.get('version')!r} "
          f"contractVersion={payload.get('contractVersion')!r}")
    print(f"     llmConfigured={payload.get('llmConfigured')!r} "
          f"providers={payload.get('providers')!r}")
    return ok, payload


def validate_plan_response(payload: dict[str, Any]) -> list[str]:
    """Return a list of contract problems found in a 200 response."""
    problems: list[str] = []
    if payload.get("contractVersion") != 1:
        problems.append("contractVersion is not 1")
    source = payload.get("source")
    if source not in {"llm", "rules", "rules_fallback"}:
        problems.append(f"unexpected source {source!r}")
    plan = payload.get("plan")
    if not isinstance(plan, dict):
        problems.append("plan is missing or not an object")
        return problems
    if plan.get("source") != source:
        problems.append("plan.source does not equal envelope source")
    if not isinstance(plan.get("summary"), str) or not plan["summary"]:
        problems.append("plan.summary is missing")
    if not isinstance(plan.get("disclaimer"), str) or "not medical advice" not in plan["disclaimer"]:
        problems.append("plan.disclaimer is not the server-owned disclaimer")
    if not isinstance(plan.get("deload"), bool):
        problems.append("plan.deload is missing")
    meta = payload.get("meta")
    if not isinstance(meta, dict) or "latencyMs" not in meta:
        problems.append("meta is missing")
    return problems


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    base_url = args.base_url.rstrip("/")
    print(f"StrongSense coach smoke test -> {base_url}")

    healthy, health_payload = check_health(base_url, HEALTH_TIMEOUT_SECONDS)
    if not healthy:
        print("FAIL: /health did not return status=ok")
        return 1
    if args.health_only:
        print("PASS: health check")
        return 0

    request_path = Path(args.request_file)
    try:
        payload = json.loads(request_path.read_text(encoding="utf-8"))
    except OSError as exc:
        print(f"FAIL: cannot read request fixture {request_path}: {exc}")
        return 1
    except json.JSONDecodeError as exc:
        print(f"FAIL: request fixture is not valid JSON: {exc}")
        return 1

    if args.force_rules:
        payload["forceRules"] = True

    print(f"POST /v1/coach/plan    -> sending {request_path} (forceRules={payload.get('forceRules', False)})")
    status, response = request_json(
        "POST",
        f"{base_url}/v1/coach/plan",
        payload=payload,
        token=args.token,
        timeout=args.timeout,
    )
    if args.print_response:
        print(json.dumps(response, indent=2, ensure_ascii=False))

    if status != 200:
        code = _error_code(response)
        message = response.get("detail", {}).get("message") if isinstance(response.get("detail"), dict) else ""
        print(f"FAIL: HTTP {status} code={code!r} message={message!r}")
        if code == "llm_not_configured":
            print("      The server is healthy but has no LLM configured. "
                  "Add provider keys to server/coach_api/.env (see .env.example).")
            return 2
        return 1

    problems = validate_plan_response(response)
    plan = response.get("plan", {})
    meta = response.get("meta", {})
    adjustments = plan.get("adjustments", [])
    tips = plan.get("tips", [])
    print(f"      source={response.get('source')!r} "
          f"provider={meta.get('provider')!r} model={meta.get('model')!r} "
          f"latencyMs={meta.get('latencyMs')!r} clamped={meta.get('clamped')!r} "
          f"droppedAdjustments={meta.get('droppedAdjustments')!r}")
    print(f"      adjustments={len(adjustments) if isinstance(adjustments, list) else '?'} "
          f"tips={len(tips) if isinstance(tips, list) else '?'} "
          f"deload={plan.get('deload')!r}")
    summary = plan.get("summary")
    if isinstance(summary, str):
        print(f"      summary: {summary[:160]}{'...' if len(summary) > 160 else ''}")
    if problems:
        for problem in problems:
            print(f"FAIL: {problem}")
        return 1

    if payload.get("forceRules") and response.get("source") != "rules":
        print(f"FAIL: forceRules=true returned source={response.get('source')!r}, expected 'rules'")
        return 1
    if not payload.get("forceRules") and plan.get("source") not in {"llm", "rules_fallback"}:
        print(f"FAIL: unexpected source {plan.get('source')!r}")
        return 1
    if response.get("source") == "rules_fallback" and not args.allow_fallback:
        print(
            "FAIL: the server returned the deterministic rules fallback, so the AI path "
            "was not used. Check the server's `llmError` log or run:\n"
            "      python scripts/check_llm.py"
        )
        return 1
    if response.get("source") == "rules_fallback":
        print("WARN: source=rules_fallback accepted because --allow-fallback was set")

    print("PASS: coach plan response is contract-shaped")
    return 0


if __name__ == "__main__":
    sys.exit(main())
