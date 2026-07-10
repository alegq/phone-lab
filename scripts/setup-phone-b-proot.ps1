# One-time / maintenance: install proot Debian + RabbitMQ 3.x on phone-b via SSH.
# Prereq: mesh.env, SSH keys (npm run remote:setup), Termux open on phone-b.

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "lib\ensure-lf.ps1")

$Root = Split-Path -Parent $PSScriptRoot
$ScriptsDir = Join-Path $Root "scripts\termux\phone-b"

Write-Host "=== Phone Lab: setup phone-b proot RabbitMQ ===" -ForegroundColor Cyan

Write-Host "Normalizing .sh line endings (LF)..."
Convert-ShFilesToLf -Directory $ScriptsDir

Push-Location $Root
try {
    $timeout = 3600
    Write-Host "Uploading scripts and running full proot setup (may take 20-45 min)..."
    python (Join-Path $PSScriptRoot "remote\deploy_phone_b_stack.py") --action full --timeout $timeout
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
} finally {
    Pop-Location
}

Write-Host ""
Write-Host "From dev PC:" -ForegroundColor Yellow
Write-Host "  npm run smoke:gateway"
Write-Host "  `$env:AGENTS_MODE='prod'; npm run smoke"
Write-Host "  npm run smoke:phase7"
Write-Host "Done." -ForegroundColor Green
