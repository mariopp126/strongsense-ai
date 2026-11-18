"""Application settings loaded from environment variables and ``.env``.

Every setting is documented in ``.env.example``. Secrets are wrapped in
``pydantic.SecretStr`` so they never appear in ``repr()`` output, and this module
never logs settings objects.
"""

from __future__ import annotations

import json
import logging
from functools import lru_cache
from pathlib import Path
from typing import Any

from pydantic import Field, SecretStr, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

from app.schemas import SERVICE_NAME, SERVICE_VERSION

logger = logging.getLogger("strongsense.coach")

#: Resolve ``.env`` next to the package, independent of the current directory.
ENV_FILE = Path(__file__).resolve().parent.parent / ".env"

PROVIDER_OPENAI_COMPATIBLE = "openai_compatible"
PROVIDER_ANTHROPIC = "anthropic"
SUPPORTED_PROVIDERS = (PROVIDER_OPENAI_COMPATIBLE, PROVIDER_ANTHROPIC)

DEFAULT_ALLOWED_ORIGINS = "http://localhost:5173,http://127.0.0.1:5173"

_OPTIONAL_SECRET_FIELDS = ("coach_api_token", "llm_api_key", "llm_fallback_api_key")
_STRING_FIELDS = (
    "app_env",
    "coach_host",
    "allowed_origins",
    "llm_provider",
    "llm_base_url",
    "llm_model",
    "llm_fallback_provider",
    "llm_fallback_base_url",
    "llm_fallback_model",
    "database_url",
)


class Settings(BaseSettings):
    """Runtime configuration for the coach service."""

    model_config = SettingsConfigDict(
        env_file=str(ENV_FILE),
        env_file_encoding="utf-8",
        extra="ignore",
        case_sensitive=False,
        validate_default=True,
    )

    # --- Server ---------------------------------------------------------
    app_env: str = "development"
    coach_host: str = "127.0.0.1"
    coach_port: int = Field(default=8080, ge=1, le=65535)
    coach_api_token: SecretStr | None = None
    allowed_origins: str = DEFAULT_ALLOWED_ORIGINS
    max_requests_per_min: int = Field(default=30, ge=0)

    # --- Primary LLM provider ------------------------------------------
    llm_provider: str = ""
    llm_base_url: str = ""
    llm_api_key: SecretStr | None = None
    llm_model: str = ""
    llm_timeout_seconds: float = Field(default=20.0, gt=0.0, le=120.0)
    llm_temperature: float = Field(default=0.4, ge=0.0, le=2.0)
    llm_max_tokens: int = Field(default=900, ge=1, le=32_000)

    # --- Optional fallback LLM provider --------------------------------
    llm_fallback_provider: str = ""
    llm_fallback_base_url: str = ""
    llm_fallback_api_key: SecretStr | None = None
    llm_fallback_model: str = ""

    # --- Optional PostgreSQL plan cache ------------------------------------
    database_url: str = ""
    # --- Validators ----------------------------------------------------
    @field_validator(*_STRING_FIELDS, mode="before")
    @classmethod
    def _strip_strings(cls, value: Any) -> Any:
        if isinstance(value, str):
            return value.strip()
        return value

    @field_validator(*_OPTIONAL_SECRET_FIELDS, mode="before")
    @classmethod
    def _blank_secret_to_none(cls, value: Any) -> Any:
        if value is None:
            return None
        if isinstance(value, SecretStr):
            return value
        if isinstance(value, str) and not value.strip():
            return None
        return value

    @field_validator("llm_provider", "llm_fallback_provider", mode="after")
    @classmethod
    def _validate_provider(cls, value: str) -> str:
        if value and value not in SUPPORTED_PROVIDERS:
            supported = ", ".join(SUPPORTED_PROVIDERS)
            raise ValueError(f"provider must be one of: {supported} (got {value!r})")
        return value

    # --- Derived helpers ----------------------------------------------
    @property
    def allowed_origin_list(self) -> list[str]:
        """``ALLOWED_ORIGINS`` parsed as a JSON array or a comma separated list."""
        raw = self.allowed_origins.strip()
        if not raw:
            return []
        if raw.startswith("["):
            try:
                parsed = json.loads(raw)
            except json.JSONDecodeError:
                parsed = None
            if isinstance(parsed, list):
                return [str(item).strip() for item in parsed if str(item).strip()]
        return [item.strip() for item in raw.split(",") if item.strip()]

    @property
    def api_token_value(self) -> str | None:
        """The configured bearer token, or None when auth is disabled."""
        return self.coach_api_token.get_secret_value() if self.coach_api_token else None

    @property
    def primary_configured(self) -> bool:
        return self._is_configured(
            self.llm_provider,
            self.llm_base_url,
            self.llm_model,
            self.llm_api_key,
        )

    @property
    def fallback_configured(self) -> bool:
        return self._is_configured(
            self.llm_fallback_provider,
            self.llm_fallback_base_url,
            self.llm_fallback_model,
            self.llm_fallback_api_key,
        )

    @property
    def llm_configured(self) -> bool:
        """True when at least one usable provider profile is configured."""
        return self.primary_configured or self.fallback_configured

    def providers(self) -> list[dict[str, str]]:
        """Provider/model pairs for ``GET /health``. Never exposes keys."""
        result: list[dict[str, str]] = []
        if self.primary_configured:
            result.append({"name": self.llm_provider, "model": self.llm_model})
        if self.fallback_configured:
            result.append(
                {"name": self.llm_fallback_provider, "model": self.llm_fallback_model}
            )
        return result

    @staticmethod
    def _is_configured(
        provider: str,
        base_url: str,
        model: str,
        api_key: SecretStr | None,
    ) -> bool:
        if provider not in SUPPORTED_PROVIDERS:
            return False
        if not base_url or not model:
            return False
        # OpenAI-compatible endpoints such as a local Ollama do not need a key.
        return not (provider == PROVIDER_ANTHROPIC and api_key is None)

    def log_summary(self) -> dict[str, object]:
        """Safe, key-free summary used once at startup."""
        return {
            "service": SERVICE_NAME,
            "version": SERVICE_VERSION,
            "app_env": self.app_env,
            "llm_configured": self.llm_configured,
            "providers": self.providers(),
            "auth_enabled": self.api_token_value is not None,
            "rate_limit_per_min": self.max_requests_per_min,
        }


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    """Return the process-wide settings instance (cached)."""
    return Settings()


def clear_settings_cache() -> None:
    """Clear the cached settings (used by tests)."""
    get_settings.cache_clear()
