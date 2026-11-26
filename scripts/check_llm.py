#!/usr/bin/env python3
"""Probe every configured LLM provider without starting the API server.

The script loads the same ``server/coach_api/.env`` as the service, sends a tiny
chat request to each configured provider/model and reports a stable failure
category (``auth_rejected``, ``model_not_found``, ``quota_exceeded``, ...).
It never prints an API key.

Usage (from the repository root, with the server dependencies installed):

    python scripts/check_llm.py
    python scripts/check_llm.py --json
    python scripts/check_llm.py --timeout 15

Exit codes:
    0  every configured provider answered
    1  at least one provider failed
    2  no provider is configured
"""

from __future__ import annotations

import argparse
import asyncio
import json
import sys
from pathlib import Path
from typing import Any
from urllib.parse import urlsplit

REPO_ROOT = Path(__file__).resolve().parents[1]
SERVER_DIR = REPO_ROOT / "server" / "coach_api"
sys.path.insert(0, str(SERVER_DIR))

from app.config import Settings  # noqa: E402
from app.llm import (  # noqa: E402
    ProviderProbeResult,
    ProviderProfile,
    probe_profile,
    resolve_profiles,
)


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Probe the configured coach LLM providers (never prints keys).",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "--timeout",
        type=float,
        default=10.0,
        help="Per-provider HTTP timeout in seconds (default: 10)",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Print machine-readable JSON instead of a table",
    )
    return parser.parse_args(argv)


def _host(base_url: str) -> str:
    """Return only the host[:port], so query-string credentials never leak."""
    parts = urlsplit(base_url if "://" in base_url else f"http://{base_url}")
    return parts.netloc or parts.path or "<unknown>"


def _print_table(results: list[ProviderProbeResult], profiles: list[ProviderProfile]) -> None:
    hosts = {profile.name: _host(profile.base_url) for profile in profiles}
    print(f"{'PROVIDER':<20} {'MODEL':<28} {'HOST':<32} RESULT")
    print("-" * 96)
    for result in results:
        status = "OK" if result.ok else f"FAIL ({result.category})"
        print(
            f"{result.name:<20} {result.model:<28} "
            f"{hosts.get(result.name, '<unknown>'):<32} {status}"
        )
        if not result.ok:
            print(f"    {result.detail}")
        else:
            print(f"    {result.latency_ms} ms -> {result.detail!r}")


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    try:
        settings = Settings()
    except Exception as exc:  # noqa: BLE001 - config errors must be readable
        print(f"FAIL: could not load server settings: {exc}")
        return 1

    profiles = resolve_profiles(settings)
    if not profiles:
        message = (
            "No provider is configured. Set LLM_PROVIDER, LLM_BASE_URL, LLM_MODEL "
            "(and LLM_API_KEY for remote endpoints) in server/coach_api/.env."
        )
        if args.json:
            print(json.dumps({"ok": False, "category": "not_configured", "error": message}))
        else:
            print(f"FAIL: {message}")
        return 2

    results = asyncio.run(_probe_all(profiles, args.timeout))
    ok = all(result.ok for result in results)

    if args.json:
        print(
            json.dumps(
                {
                    "ok": ok,
                    "providers": [
                        {
                            "name": result.name,
                            "model": result.model,
                            "host": _host(profile.base_url),
                            "ok": result.ok,
                            "category": result.category,
                            "detail": result.detail,
                            "latencyMs": result.latency_ms,
                        }
                        for result, profile in zip(results, profiles, strict=True)
                    ],
                },
                indent=2,
            )
        )
    else:
        _print_table(results, profiles)
        if ok:
            print("\nPASS: every configured provider answered.")
        else:
            print(
                "\nFAIL: at least one provider failed. Check the category above; "
                "run the API server and inspect its `llmError` log for the full reason."
            )
    return 0 if ok else 1


async def _probe_all(
    profiles: list[ProviderProfile], timeout: float
) -> list[ProviderProbeResult]:
    results: list[ProviderProbeResult] = []
    for profile in profiles:
        results.append(await probe_profile(profile, timeout=timeout))
    return results


if __name__ == "__main__":
    sys.exit(main())
