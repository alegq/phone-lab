# Package prod api-agents for phone-b deployment (phase 7).
# Run from phone-lab repo root.
# Builds ../api-agents on PC - do NOT copy Windows node_modules to phone.

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "lib\ensure-lf.ps1")
$PhoneLabRoot = Split-Path -Parent $PSScriptRoot
$AgentsRoot = Join-Path (Split-Path -Parent $PhoneLabRoot) "api-agents"
$Staging = Join-Path $PhoneLabRoot "staging\api-agents-prod"
$OutTgz = Join-Path $PhoneLabRoot "agents-prod.tgz"
$EnvExample = Join-Path $PhoneLabRoot "config\agents-prod.phone-b.env.example"
$TermuxScripts = Join-Path $PhoneLabRoot "scripts\termux\phone-b"

Write-Host "=== Phone Lab: deploy prod api-agents (phase 7) ===" -ForegroundColor Cyan

if (-not (Test-Path $AgentsRoot)) {
  Write-Error "api-agents not found at $AgentsRoot"
}

Write-Host "Building api-agents..."
Push-Location $AgentsRoot
npm ci
npm run build
if ($LASTEXITCODE -ne 0) { Pop-Location; exit $LASTEXITCODE }
Pop-Location

if (-not (Test-Path (Join-Path $AgentsRoot "dist\main.js"))) {
  Write-Error "Build failed: dist/main.js not found"
}

Write-Host "Staging package..."
if (Test-Path $Staging) { Remove-Item -Recurse -Force $Staging }
New-Item -ItemType Directory -Path $Staging -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $Staging "scripts\termux\phone-b") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $Staging "config") -Force | Out-Null

Copy-Item -Recurse (Join-Path $AgentsRoot "dist") (Join-Path $Staging "dist")
Copy-Item (Join-Path $AgentsRoot "package.json") $Staging
Copy-Item (Join-Path $AgentsRoot "package-lock.json") $Staging
Copy-Item $EnvExample (Join-Path $Staging ".env.example")
Copy-Item (Join-Path $PhoneLabRoot "config\agents-prod.phone-b.env.*.example") (Join-Path $Staging "config")
Copy-Item "$TermuxScripts\*" (Join-Path $Staging "scripts\termux\phone-b")

$GitSha = ""
Push-Location $AgentsRoot
try {
    $GitSha = (git rev-parse HEAD 2>$null)
    if ($LASTEXITCODE -ne 0) { $GitSha = "" }
} finally {
    Pop-Location
}
$ShortSha = if ($GitSha.Length -ge 7) { $GitSha.Substring(0, 7) } else { "unknown" }
$BuiltAt = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
$ReleaseMeta = @(
    "SERVICE=api-agents-prod",
    "SHA=$GitSha",
    "SHORT_SHA=$ShortSha",
    "BUILT_AT=$BuiltAt",
    "SOURCE=manual"
)
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllLines((Join-Path $Staging ".phone-lab-release"), $ReleaseMeta, $utf8NoBom)

Write-Host "Normalizing .sh line endings (LF)..."
Convert-ShFilesToLf -Directory $Staging

if (Get-Command tar -ErrorAction SilentlyContinue) {
  Push-Location $PhoneLabRoot
  if (Test-Path agents-prod.tgz) { Remove-Item agents-prod.tgz }
  tar -czf agents-prod.tgz -C staging/api-agents-prod .
  Pop-Location
  Write-Host "Created: $OutTgz"
} else {
  Write-Host "WARN: tar not found"
}

Write-Host ""
Write-Host "On phone-b-agents in Termux:" -ForegroundColor Yellow
Write-Host "  mkdir -p ~/phone-lab/packages/api-agents-prod"
Write-Host "  cd ~/phone-lab/packages/api-agents-prod"
Write-Host "  tar -xzf ~/storage/downloads/Telegram/agents-prod.tgz"
Write-Host "  npm install --omit=dev"
Write-Host "  cp .env.example .env"
Write-Host "  bash scripts/termux/phone-b/setup-data-plane.sh    # once"
Write-Host "  bash scripts/termux/phone-b/install-boot-stack.sh  # optional"
Write-Host "  bash scripts/termux/phone-b/boot-stack-phone-b.sh"
Write-Host ""
Write-Host "From dev PC: npm run smoke:phase7"
Write-Host "Content: deploy with npm run deploy:phase13 (see docs/PHASE-13-DEPLOY.md)"
Write-Host "From dev PC: npm run smoke:phase8"
Write-Host "Done." -ForegroundColor Green
