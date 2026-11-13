#!/usr/bin/env pwsh
<#
.SYNOPSIS
  Developer shortcuts for StrongSense AI.

.EXAMPLES
  ./scripts/dev.ps1 run-web
  ./scripts/dev.ps1 run-server
  ./scripts/dev.ps1 test
  ./scripts/dev.ps1 format
  ./scripts/dev.ps1 build-web
#>

param(
  [Parameter(Position = 0)]
  [ValidateSet('run-web', 'run-android', 'run-server', 'test', 'format', 'build-web', 'build-apk', 'doctor')]
  [string]$Command = 'run-web'
)

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent $PSScriptRoot
$AppDir = Join-Path $RepoRoot 'apps/strongsense'
$CoreDir = Join-Path $RepoRoot 'packages/strongsense_core'
$ServerDir = Join-Path $RepoRoot 'server/coach_api'
$VenvPython = Join-Path $ServerDir '.venv/Scripts/python.exe'

function Ensure-ServerVenv {
  if (-not (Test-Path $VenvPython)) {
    Write-Host 'Creating the coach API virtual environment...'
    python -m venv (Join-Path $ServerDir '.venv')
    & $VenvPython -m pip install --upgrade pip | Out-Null
    & $VenvPython -m pip install -r (Join-Path $ServerDir 'requirements-dev.txt')
  }
}

function Invoke-Core {
  Push-Location $CoreDir
  try {
    dart pub get
    dart analyze --fatal-infos
    dart test
  } finally {
    Pop-Location
  }
}

function Invoke-App {
  Push-Location $AppDir
  try {
    flutter pub get
    flutter analyze --fatal-infos
    flutter test
  } finally {
    Pop-Location
  }
}

function Invoke-ServerTests {
  Ensure-ServerVenv
  Push-Location $ServerDir
  try {
    & $VenvPython -m ruff check .
    & $VenvPython -m mypy app
    & $VenvPython -m pytest --cov=app --cov-report=term-missing --cov-fail-under=85
  } finally {
    Pop-Location
  }
}

switch ($Command) {
  'run-web' {
    Push-Location $AppDir
    try { flutter run -d chrome --web-port 5173 } finally { Pop-Location }
  }
  'run-android' {
    Push-Location $AppDir
    try { flutter run } finally { Pop-Location }
  }
  'run-server' {
    Ensure-ServerVenv
    Push-Location $ServerDir
    try {
      & $VenvPython -m uvicorn app.main:app --host 127.0.0.1 --port 8080 --reload
    } finally {
      Pop-Location
    }
  }
  'test' {
    Invoke-Core
    Invoke-App
    Invoke-ServerTests
    Write-Host 'All checks passed.' -ForegroundColor Green
  }
  'format' {
    dart format (Join-Path $AppDir 'lib') (Join-Path $AppDir 'test')
    dart format (Join-Path $CoreDir 'lib') (Join-Path $CoreDir 'test')
    if (Test-Path $VenvPython) {
      Push-Location $ServerDir
      try { & $VenvPython -m ruff format . } finally { Pop-Location }
    }
  }
  'build-web' {
    Push-Location $AppDir
    try { flutter build web --release } finally { Pop-Location }
  }
  'build-apk' {
    Push-Location $AppDir
    try { flutter build apk --release } finally { Pop-Location }
  }
  'doctor' {
    flutter --version
    dart --version
    python --version
  }
}
