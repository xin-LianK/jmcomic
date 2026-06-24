$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$backend = Join-Path $root "backend"
$venvPython = Join-Path $backend ".venv\Scripts\python.exe"

if (-not (Test-Path $venvPython)) {
  python -m venv (Join-Path $backend ".venv")
}

& $venvPython -m pip install -r (Join-Path $backend "requirements.txt")

if (-not $env:JMCOMIC_SOURCE) {
  $candidate = "D:\demo\workspace\JMComic-Crawler-Python\src"
  if (Test-Path $candidate) {
    $env:JMCOMIC_SOURCE = $candidate
  }
}

Set-Location $backend
& $venvPython -m uvicorn jm_server.app:app --host 127.0.0.1 --port 8766 --reload
