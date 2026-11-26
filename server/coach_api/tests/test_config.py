"""Settings parsing, secrets and provider helpers."""

from __future__ import annotations

import json
from collections.abc import Callable
from pathlib import Path
from typing import Any

import pytest
from app.config import ENV_FILE, Settings, get_settings
from app.schemas import SERVICE_NAME, SERVICE_VERSION
from pydantic import ValidationError


def test_defaults(make_settings: Callable[..., Settings]) -> None:
    settings = make_settings()
    assert settings.app_env == "test"
    assert settings.coach_host == "127.0.0.1"
    assert settings.coach_port == 8080
    assert settings.allowed_origin_list == [
        "http://localhost:5173",
        "http://127.0.0.1:5173",
    ]
    assert settings.llm_configured is False
    assert settings.providers() == []
    assert settings.api_token_value is None


def test_allowed_origins_accepts_json_array() -> None:
    settings = Settings(
        _env_file=None,
        allowed_origins='["https://app.example.com", "https://admin.example.com"]',
    )
    assert settings.allowed_origin_list == [
        "https://app.example.com",
        "https://admin.example.com",
    ]


def test_allowed_origins_blank() -> None:
    settings = Settings(_env_file=None, allowed_origins="  ")
    assert settings.allowed_origin_list == []


def test_openai_compatible_without_key_is_configured(
    make_settings: Callable[..., Settings],
) -> None:
    settings = make_settings(
        llm_provider="openai_compatible",
        llm_base_url="http://localhost:11434/v1",
        llm_model="llama3.1:8b",
        llm_api_key=None,
    )
    assert settings.llm_configured is True
    assert settings.providers() == [{"name": "openai_compatible", "model": "llama3.1:8b"}]


def test_openai_compatible_remote_without_key_is_not_configured(
    make_settings: Callable[..., Settings],
) -> None:
    # Remote OpenAI-compatible endpoints require an API key.
    settings = make_settings(
        llm_provider="openai_compatible",
        llm_base_url="https://api.openai.com/v1",
        llm_model="gpt-4.1-mini",
        llm_api_key=None,
    )
    assert settings.llm_configured is False
    assert settings.providers() == []

    # Same for any non-localhost remote host.
    settings = make_settings(
        llm_provider="openai_compatible",
        llm_base_url="https://openrouter.ai/api/v1",
        llm_model="openai/gpt-4.1-mini",
        llm_api_key=None,
    )
    assert settings.llm_configured is False


def test_openai_compatible_remote_with_key_is_configured(
    make_settings: Callable[..., Settings],
) -> None:
    settings = make_settings(
        llm_provider="openai_compatible",
        llm_base_url="https://api.openai.com/v1",
        llm_model="gpt-4.1-mini",
        llm_api_key="sk-test-key",
    )
    assert settings.llm_configured is True
    assert settings.providers() == [
        {"name": "openai_compatible", "model": "gpt-4.1-mini"}
    ]


def test_anthropic_requires_key(make_settings: Callable[..., Settings]) -> None:
    without_key = make_settings(
        llm_provider="anthropic",
        llm_base_url="https://api.anthropic.com",
        llm_model="claude-test",
        llm_api_key=None,
    )
    assert without_key.llm_configured is False
    with_key = make_settings(
        llm_provider="anthropic",
        llm_base_url="https://api.anthropic.com",
        llm_model="claude-test",
        llm_api_key="sk-ant-test",
    )
    assert with_key.llm_configured is True


def test_missing_base_url_or_model_is_not_configured(
    make_settings: Callable[..., Settings],
) -> None:
    assert (
        make_settings(
            llm_provider="openai_compatible",
            llm_base_url="",
            llm_model="m",
            llm_api_key="k",
        ).llm_configured
        is False
    )
    assert (
        make_settings(
            llm_provider="openai_compatible",
            llm_base_url="https://x/v1",
            llm_model="",
            llm_api_key="k",
        ).llm_configured
        is False
    )


def test_unknown_provider_rejected() -> None:
    with pytest.raises(ValidationError):
        Settings(_env_file=None, llm_provider="not_a_provider")


def test_default_max_tokens_fits_reasoning_models() -> None:
    # Gemini 3 / o-series spend hidden thinking tokens from the same budget; the old
    # 900-token default truncated the JSON plan (finish_reason=length).
    settings = Settings(_env_file=None)
    assert settings.llm_max_tokens == 4096


def test_blank_secrets_become_none(make_settings: Callable[..., Settings]) -> None:
    settings = make_settings(llm_api_key="", coach_api_token="   ")
    assert settings.llm_api_key is None
    assert settings.coach_api_token is None


def test_strings_are_stripped(make_settings: Callable[..., Settings]) -> None:
    settings = make_settings(llm_base_url="  https://api.example.com/v1  ", llm_model=" m ")
    assert settings.llm_base_url == "https://api.example.com/v1"
    assert settings.llm_model == "m"


def test_repr_and_log_summary_never_expose_secrets(
    make_settings: Callable[..., Settings],
) -> None:
    settings = make_settings(
        llm_provider="openai_compatible",
        llm_base_url="https://api.example.com/v1",
        llm_model="gpt-test",
        llm_api_key="sk-very-secret-value",
        coach_api_token="coach-very-secret",
    )
    renderings = (
        repr(settings),
        str(settings.model_dump()),
        json.dumps(settings.log_summary()),
    )
    for rendered in renderings:
        assert "sk-very-secret-value" not in rendered
        assert "coach-very-secret" not in rendered
    assert settings.log_summary()["auth_enabled"] is True
    assert settings.log_summary()["llm_configured"] is True


def test_env_file_is_next_to_the_package() -> None:
    assert ENV_FILE.name == ".env"
    assert ENV_FILE.parent.name == "coach_api"
    assert isinstance(ENV_FILE, Path)


def test_get_settings_is_cached() -> None:
    get_settings.cache_clear()
    first = get_settings()
    second = get_settings()
    assert first is second
    get_settings.cache_clear()


def test_log_summary_metadata(make_settings: Callable[..., Settings]) -> None:
    settings = make_settings(app_env="production", max_requests_per_min=7)
    summary: dict[str, Any] = settings.log_summary()
    assert summary["service"] == SERVICE_NAME
    assert summary["version"] == SERVICE_VERSION
    assert summary["app_env"] == "production"
    assert summary["rate_limit_per_min"] == 7
    assert summary["providers"] == []
