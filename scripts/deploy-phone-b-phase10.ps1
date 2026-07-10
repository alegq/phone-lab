# Phase 10 — deploy live agents stack on phone-b via SSH.
# Run from phone-lab repo root.
#
# Prerequisites: mesh.env, mesh.secrets.env (GEMINI_API_KEY), SSH keys (npm run remote:setup)
# Content is deployed separately via deploy:phase13 (typically on phone-a).

param(
    [switch]$SkipSmoke,
    [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$SecretsFile = Join-Path $Root "mesh.secrets.env"

function Read-EnvFile([string]$Path) {
    $vars = @{}
    if (-not (Test-Path $Path)) { return $vars }
    Get-Content $Path | ForEach-Object {
        $line = $_.Trim()
        if (-not $line -or $line.StartsWith("#")) { return }
        $eq = $line.IndexOf("=")
        if ($eq -lt 0) { return }
        $vars[$line.Substring(0, $eq).Trim()] = $line.Substring($eq + 1).Trim()
    }
    return $vars
}

Write-Host "=== Phone Lab: deploy phase 10 (live agents on phone-b) ===" -ForegroundColor Cyan

$secrets = Read-EnvFile $SecretsFile
if (-not $secrets["GEMINI_API_KEY"]) {
    Write-Error "GEMINI_API_KEY required in mesh.secrets.env"
}

if (-not $SkipBuild) {
    & (Join-Path $PSScriptRoot "deploy-agents-prod.ps1")
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

$agentsTgz = Join-Path $Root "agents-prod.tgz"
if (-not (Test-Path $agentsTgz)) { Write-Error "Missing $agentsTgz — run deploy-agents-prod.ps1" }

Write-Host "Uploading agents-prod archive to phone-b..."
python (Join-Path $PSScriptRoot "remote\ssh_upload.py") phone-b $agentsTgz "~/agents-prod.tgz"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "Extracting agents-prod on phone-b..."
& (Join-Path $PSScriptRoot "remote-exec.ps1") phone-b "mkdir -p ~/phone-lab/packages/api-agents-prod && cd ~/phone-lab/packages/api-agents-prod && tar -xzf ~/agents-prod.tgz"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "npm install on phone-b (may take 10-20 min)..."
& (Join-Path $PSScriptRoot "remote-exec.ps1") phone-b "cd ~/phone-lab/packages/api-agents-prod && npm install --omit=dev"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "Applying live env profile..."
& (Join-Path $PSScriptRoot "apply-phone-b-env.ps1") -Profile live
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "Starting boot stack + restart agents on phone-b..."
& (Join-Path $PSScriptRoot "remote-exec.ps1") phone-b "bash ~/phone-lab/packages/api-agents-prod/scripts/termux/phone-b/boot-stack-phone-b.sh"
if ($LASTEXITCODE -ne 0) { Write-Host "WARN: boot-stack returned $LASTEXITCODE" }
& (Join-Path $PSScriptRoot "remote-exec.ps1") phone-b "bash ~/phone-lab/packages/api-agents-prod/scripts/termux/phone-b/restart-agents-prod.sh"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "Waiting 60s for stack..."
Start-Sleep -Seconds 60

& (Join-Path $PSScriptRoot "remote-exec.ps1") phone-b "tail -20 ~/phone-lab/logs/agents-prod.log"
if ($LASTEXITCODE -ne 0) { Write-Host "WARN: could not tail agents-prod.log" }

Push-Location $Root
try {
    npm run preflight:gemini
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    if (-not $SkipSmoke) {
        Write-Host "`nStarting smoke:phase10 (30-60 min)..." -ForegroundColor Yellow
        npm run smoke:phase10
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }
} finally {
    Pop-Location
}

Write-Host "`nPhase 10 deploy complete." -ForegroundColor Green
