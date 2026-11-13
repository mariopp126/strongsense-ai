# ---------------------------------------------------------------------------
# StrongSense Coach API - interactive .env setup
# ---------------------------------------------------------------------------
# Writes server/coach_api/.env with your provider settings. API keys are read with
# Read-Host -AsSecureString and are never echoed, never printed back and never
# written to the console history.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File scripts\set_keys.ps1   # interactive
#   powershell -ExecutionPolicy Bypass -File scripts\set_keys.ps1 -Help
#   powershell -ExecutionPolicy Bypass -File scripts\set_keys.ps1 -NonInteractive -Provider openai -BaseUrl ... -Model ... -ApiKey ...
#   powershell -ExecutionPolicy Bypass -File scripts\set_keys.ps1 -Force
#
# The .env file is gitignored by the repository root .gitignore. Never commit it.
# ---------------------------------------------------------------------------
[CmdletBinding()]
param(
    [switch]$Help,
    [ValidateSet('openai', 'deepseek', 'openrouter', 'groq', 'gemini', 'ollama', 'anthropic', 'custom', '')]
    [string]$Provider = '',
    [string]$BaseUrl = '',
    [string]$Model = '',
    [string]$ApiKey = '',
    [string]$CoachApiToken = '',
    [string]$EnvFile = '',
    [switch]$NonInteractive,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

function Show-Usage {
    Write-Host @'
StrongSense Coach API - .env setup

Writes server/coach_api/.env with the LLM provider configuration. Keys are read
securely and are never echoed.

Parameters:
  -Provider <openai|deepseek|openrouter|groq|gemini|ollama|anthropic|custom>
  -BaseUrl <url>            Provider base URL (presets are filled in for you)
  -Model <model-id>         Provider model name
  -ApiKey <key>             API key (omit to be prompted securely; aliases: -ApiKey)
  -CoachApiToken <token>    Optional bearer token the app must send (empty = auth off)
  -EnvFile <path>           Target file (default: server/coach_api/.env)
  -NonInteractive           Fail instead of prompting for missing values
  -Force                    Overwrite an existing .env without asking
  -Help                     Show this help

Examples:
  powershell -ExecutionPolicy Bypass -File scripts\set_keys.ps1
  powershell -ExecutionPolicy Bypass -File scripts\set_keys.ps1 -Provider deepseek -Model deepseek-chat
  powershell -ExecutionPolicy Bypass -File scripts\set_keys.ps1 -Provider ollama -Model llama3.1:8b

After running, start the service:
  cd server/coach_api
  .\.venv\Scripts\uvicorn app.main:app --host 127.0.0.1 --port 8080
'@
}

function Read-SecureValue {
    param([string]$Prompt)
    $secure = Read-Host -Prompt $Prompt -AsSecureString
    if ($null -eq $secure) {
        return ''
    }
    $credential = New-Object System.Net.NetworkCredential('', $secure)
    return [string]$credential.Password
}

if ($Help) {
    Show-Usage
    exit 0
}

$repoRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($EnvFile)) {
    $EnvFile = Join-Path (Join-Path $repoRoot 'server') 'coach_api/.env'
}
$EnvFile = [System.IO.Path]::GetFullPath($EnvFile)

# --- Provider presets ------------------------------------------------------
$presets = @{
    'openai'     = @{ Type = 'openai_compatible'; BaseUrl = 'https://api.openai.com/v1';        Model = 'gpt-4.1-mini' }
    'deepseek'   = @{ Type = 'openai_compatible'; BaseUrl = 'https://api.deepseek.com/v1';      Model = 'deepseek-chat' }
    'openrouter' = @{ Type = 'openai_compatible'; BaseUrl = 'https://openrouter.ai/api/v1';     Model = 'openai/gpt-4.1-mini' }
    'groq'       = @{ Type = 'openai_compatible'; BaseUrl = 'https://api.groq.com/openai/v1';   Model = 'llama-3.3-70b-versatile' }
    'gemini'     = @{ Type = 'openai_compatible'; BaseUrl = 'https://generativelanguage.googleapis.com/v1beta/openai'; Model = 'gemini-2.0-flash' }
    'ollama'     = @{ Type = 'openai_compatible'; BaseUrl = 'http://127.0.0.1:11434/v1';        Model = 'llama3.1:8b' }
    'anthropic'  = @{ Type = 'anthropic';         BaseUrl = 'https://api.anthropic.com';        Model = 'claude-3-5-haiku-latest' }
    'custom'     = @{ Type = 'openai_compatible'; BaseUrl = '';                                 Model = '' }
}

if ([string]::IsNullOrWhiteSpace($Provider)) {
    if ($NonInteractive) {
        Write-Error 'Provider is required in -NonInteractive mode. Supported: openai, deepseek, openrouter, groq, gemini, ollama, anthropic, custom.'
        exit 1
    }
    Write-Host ''
    Write-Host 'Choose an LLM provider:'
    Write-Host '  1) OpenAI'
    Write-Host '  2) DeepSeek'
    Write-Host '  3) OpenRouter'
    Write-Host '  4) Groq'
    Write-Host '  5) Gemini (OpenAI-compatible endpoint)'
    Write-Host '  6) Ollama (local)'
    Write-Host '  7) Anthropic (native API)'
    Write-Host '  8) Custom OpenAI-compatible endpoint'
    $choice = Read-Host -Prompt 'Provider [1-8]'
    switch ($choice.Trim()) {
        '1' { $Provider = 'openai' }
        '2' { $Provider = 'deepseek' }
        '3' { $Provider = 'openrouter' }
        '4' { $Provider = 'groq' }
        '5' { $Provider = 'gemini' }
        '6' { $Provider = 'ollama' }
        '7' { $Provider = 'anthropic' }
        '8' { $Provider = 'custom' }
        default {
            Write-Error "Unknown provider choice '$choice'."
            exit 1
        }
    }
}

$preset = $presets[$Provider]
$providerType = $preset.Type
if ([string]::IsNullOrWhiteSpace($BaseUrl)) {
    if (-not [string]::IsNullOrWhiteSpace($preset.BaseUrl)) {
        $BaseUrl = $preset.BaseUrl
    } elseif ($NonInteractive) {
        Write-Error "-BaseUrl is required for provider 'custom' in -NonInteractive mode."
        exit 1
    } else {
        $BaseUrl = Read-Host -Prompt 'Base URL (e.g. https://api.openai.com/v1)'
    }
}
if ([string]::IsNullOrWhiteSpace($Model)) {
    if (-not [string]::IsNullOrWhiteSpace($preset.Model)) {
        $Model = $preset.Model
    } elseif ($NonInteractive) {
        Write-Error "-Model is required for provider 'custom' in -NonInteractive mode."
        exit 1
    } else {
        $Model = Read-Host -Prompt 'Model id (e.g. gpt-4.1-mini)'
    }
}

if ([string]::IsNullOrWhiteSpace($ApiKey)) {
    if ($NonInteractive) {
        if ($Provider -ne 'ollama') {
            Write-Error '-ApiKey is required in -NonInteractive mode (except for Ollama/local endpoints).'
            exit 1
        }
    } else {
        $prompt = "API key for $Provider (input hidden; press Enter to leave empty for local endpoints)"
        $ApiKey = Read-SecureValue -Prompt $prompt
    }
}
if ([string]::IsNullOrWhiteSpace($ApiKey) -and $Provider -ne 'ollama') {
    Write-Warning 'No API key set. The provider will probably reject requests; /health still reports llmConfigured=false for Anthropic.'
}

if (-not $NonInteractive -and [string]::IsNullOrWhiteSpace($CoachApiToken)) {
    Write-Host ''
    Write-Host 'Optional: a bearer token the app must send as "Authorization: Bearer <token>".'
    Write-Host 'Leave empty to keep authentication disabled (local development).'
    $CoachApiToken = Read-SecureValue -Prompt 'COACH_API_TOKEN (input hidden; Enter to skip)'
}

if ((Test-Path -LiteralPath $EnvFile) -and -not $Force) {
    if ($NonInteractive) {
        Write-Error "Refusing to overwrite existing '$EnvFile' in -NonInteractive mode. Pass -Force to replace it."
        exit 1
    }
    $answer = Read-Host -Prompt "'$EnvFile' already exists. Overwrite it? [y/N]"
    if ($answer.Trim().ToLowerInvariant() -ne 'y') {
        Write-Host 'Aborted; existing .env left untouched.'
        exit 1
    }
}

$parent = Split-Path -Parent $EnvFile
if (-not (Test-Path -LiteralPath $parent)) {
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
}

$lines = @(
    '# Generated by scripts/set_keys.ps1. Do not commit this file; it contains secrets.',
    'APP_ENV=development',
    'COACH_HOST=127.0.0.1',
    'COACH_PORT=8080',
    "COACH_API_TOKEN=$CoachApiToken",
    'ALLOWED_ORIGINS=http://localhost:5173,http://127.0.0.1:5173',
    'MAX_REQUESTS_PER_MIN=30',
    '',
    '# Primary LLM provider',
    "LLM_PROVIDER=$providerType",
    "LLM_BASE_URL=$BaseUrl",
    "LLM_API_KEY=$ApiKey",
    "LLM_MODEL=$Model",
    'LLM_TIMEOUT_SECONDS=20',
    'LLM_TEMPERATURE=0.4',
    'LLM_MAX_TOKENS=900',
    '',
    '# Optional fallback provider (left disabled)',
    'LLM_FALLBACK_PROVIDER=',
    'LLM_FALLBACK_BASE_URL=',
    'LLM_FALLBACK_API_KEY=',
    'LLM_FALLBACK_MODEL='
)

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllLines($EnvFile, $lines, $utf8NoBom)

Write-Host ''
Write-Host "Wrote configuration to: $EnvFile"
Write-Host "  provider : $providerType ($Provider)"
Write-Host "  base URL : $BaseUrl"
Write-Host "  model    : $Model"
if ([string]::IsNullOrWhiteSpace($ApiKey)) {
    Write-Host '  api key  : <empty>'
} else {
    Write-Host '  api key  : <set, hidden>'
}
if ([string]::IsNullOrWhiteSpace($CoachApiToken)) {
    Write-Host '  auth     : disabled (no COACH_API_TOKEN)'
} else {
    Write-Host '  auth     : enabled'
}
Write-Host ''
Write-Host 'The file is gitignored. Start the service with:'
Write-Host '  cd server/coach_api'
Write-Host '  .\.venv\Scripts\uvicorn app.main:app --host 127.0.0.1 --port 8080'
exit 0
