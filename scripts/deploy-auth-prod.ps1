# Package prod api-auth for phone-b deployment (phase 11).
# Run from phone-lab repo root.
# Builds ../api-auth on PC — do NOT copy Windows node_modules to phone.

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "lib\ensure-lf.ps1")
$PhoneLabRoot = Split-Path -Parent $PSScriptRoot
$AuthRoot = Join-Path (Split-Path -Parent $PhoneLabRoot) "api-auth"
$Staging = Join-Path $PhoneLabRoot "staging\api-auth-prod"
$OutTgz = Join-Path $PhoneLabRoot "auth-prod.tgz"
$EnvExample = Join-Path $PhoneLabRoot "config\auth-prod.phone-b.env.example"
$TermuxScripts = Join-Path $PhoneLabRoot "scripts\termux\phone-b"

Write-Host "=== Phone Lab: deploy prod api-auth (phase 11) ===" -ForegroundColor Cyan

if (-not (Test-Path $AuthRoot)) {
  Write-Error "api-auth not found at $AuthRoot"
}

Write-Host "Building api-auth..."
Push-Location $AuthRoot
$env:NODE_OPTIONS = "--max-old-space-size=4096"
npm ci --legacy-peer-deps
if ($LASTEXITCODE -ne 0) { Pop-Location; exit $LASTEXITCODE }
npm run build
if ($LASTEXITCODE -ne 0) { Pop-Location; exit $LASTEXITCODE }
Pop-Location
Remove-Item Env:NODE_OPTIONS -ErrorAction SilentlyContinue

$DistMain = Join-Path $AuthRoot "dist\main.js"
if (-not (Test-Path $DistMain)) {
  Write-Error "Build failed: dist/main.js not found"
}

Write-Host "Staging package..."
if (Test-Path $Staging) { Remove-Item -Recurse -Force $Staging }
New-Item -ItemType Directory -Path $Staging -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $Staging "scripts\termux\phone-b") -Force | Out-Null

Copy-Item -Recurse (Join-Path $AuthRoot "dist") (Join-Path $Staging "dist")
Copy-Item (Join-Path $AuthRoot "package.json") $Staging
Copy-Item (Join-Path $AuthRoot "package-lock.json") $Staging
Copy-Item $EnvExample (Join-Path $Staging ".env.example")

# Only include scripts that are relevant to api-auth (phase 11).
Copy-Item "$TermuxScripts\start-auth-prod.sh" (Join-Path $Staging "scripts\termux\phone-b")
Copy-Item "$TermuxScripts\restart-auth-prod.sh" (Join-Path $Staging "scripts\termux\phone-b")
Copy-Item "$TermuxScripts\setup-auth-db.sh" (Join-Path $Staging "scripts\termux\phone-b")
Copy-Item "$TermuxScripts\install-boot-auth.sh" (Join-Path $Staging "scripts\termux\phone-b")

# npm install on Android: avoid postinstall scripts (lab workaround).
Set-Content -Path (Join-Path $Staging ".npmrc") -Value "ignore-scripts=true`n" -NoNewline

Write-Host "Normalizing .sh line endings (LF)..."
Convert-ShFilesToLf -Directory $Staging

if (Get-Command tar -ErrorAction SilentlyContinue) {
  Push-Location $PhoneLabRoot
  if (Test-Path auth-prod.tgz) { Remove-Item auth-prod.tgz }
  tar -czf auth-prod.tgz -C staging/api-auth-prod .
  Pop-Location
  Write-Host "Created: $OutTgz"
} else {
  Write-Host "WARN: tar not found"
}

Write-Host ""
Write-Host "On phone-b-agents in Termux:" -ForegroundColor Yellow
Write-Host "  mkdir -p ~/phone-lab/packages/api-auth-prod"
Write-Host "  cd ~/phone-lab/packages/api-auth-prod"
Write-Host "  tar -xzf ~/storage/downloads/Telegram/auth-prod.tgz"
Write-Host "  PUPPETEER_SKIP_DOWNLOAD=true npm install --omit=dev --legacy-peer-deps --ignore-scripts"
Write-Host "  cp .env.example .env"
Write-Host "  bash scripts/termux/phone-b/setup-auth-db.sh"
Write-Host "  bash scripts/termux/phone-b/restart-auth-prod.sh"
Write-Host ""
Write-Host "From dev PC (after gateway env wired): npm run smoke:phase11"
Write-Host "Done." -ForegroundColor Green

