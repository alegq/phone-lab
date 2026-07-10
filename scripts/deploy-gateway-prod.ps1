# Package prod api-gateway for phone-a-gateway deployment (phase 9).
# Run from phone-lab repo root.
# Builds ../api-gateway on PC — do NOT copy Windows node_modules to phone.

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "lib\ensure-lf.ps1")
$PhoneLabRoot = Split-Path -Parent $PSScriptRoot
$GatewayRoot = Join-Path (Split-Path -Parent $PhoneLabRoot) "api-gateway"
$Staging = Join-Path $PhoneLabRoot "staging\api-gateway-prod"
$OutTgz = Join-Path $PhoneLabRoot "gateway-prod.tgz"
$EnvExample = Join-Path $PhoneLabRoot "config\gateway-prod.phone-a.env.example"
$TermuxScripts = Join-Path $PhoneLabRoot "scripts\termux\phone-a"

Write-Host "=== Phone Lab: deploy prod api-gateway (phase 9) ===" -ForegroundColor Cyan

if (-not (Test-Path $GatewayRoot)) {
  Write-Error "api-gateway not found at $GatewayRoot"
}

Write-Host "Building api-gateway..."
Push-Location $GatewayRoot
$env:NODE_OPTIONS = "--max-old-space-size=4096"
npm ci --legacy-peer-deps
if ($LASTEXITCODE -ne 0) { Pop-Location; exit $LASTEXITCODE }
npm run build
if ($LASTEXITCODE -ne 0) { Pop-Location; exit $LASTEXITCODE }
Pop-Location
Remove-Item Env:NODE_OPTIONS -ErrorAction SilentlyContinue

$DistMain = Join-Path $GatewayRoot "dist\main.js"
if (-not (Test-Path $DistMain)) {
  Write-Error "Build failed: dist/main.js not found"
}

Write-Host "Staging package..."
if (Test-Path $Staging) { Remove-Item -Recurse -Force $Staging }
New-Item -ItemType Directory -Path $Staging -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $Staging "scripts\termux\phone-a") -Force | Out-Null

Copy-Item -Recurse (Join-Path $GatewayRoot "dist") (Join-Path $Staging "dist")
Copy-Item (Join-Path $GatewayRoot "package.json") $Staging
Copy-Item (Join-Path $GatewayRoot "package-lock.json") $Staging
Copy-Item $EnvExample (Join-Path $Staging ".env.example")
Copy-Item "$TermuxScripts\*" (Join-Path $Staging "scripts\termux\phone-a")
Set-Content -Path (Join-Path $Staging ".npmrc") -Value "ignore-scripts=true`n" -NoNewline

# Ensure firebase service account JSON is present in dist/config
$DistConfig = Join-Path $Staging "dist\config"
New-Item -ItemType Directory -Path $DistConfig -Force | Out-Null
Copy-Item (Join-Path $GatewayRoot "src\config\ezrababait-*-firebase.json") $DistConfig -ErrorAction SilentlyContinue

Write-Host "Normalizing .sh line endings (LF)..."
Convert-ShFilesToLf -Directory $Staging

if (Get-Command tar -ErrorAction SilentlyContinue) {
  Push-Location $PhoneLabRoot
  if (Test-Path gateway-prod.tgz) { Remove-Item gateway-prod.tgz }
  tar -czf gateway-prod.tgz -C staging/api-gateway-prod .
  Pop-Location
  Write-Host "Created: $OutTgz"
} else {
  Write-Host "WARN: tar not found"
}

Write-Host ""
Write-Host "On phone-a-gateway in Termux:" -ForegroundColor Yellow
Write-Host "  mkdir -p ~/phone-lab/packages/api-gateway-prod"
Write-Host "  cd ~/phone-lab/packages/api-gateway-prod"
Write-Host "  tar -xzf ~/storage/downloads/Telegram/gateway-prod.tgz"
Write-Host "  PUPPETEER_SKIP_DOWNLOAD=true npm install --omit=dev --legacy-peer-deps --ignore-scripts"
Write-Host "  cp .env.example .env"
Write-Host "  bash scripts/termux/phone-a/install-boot-gateway.sh  # optional"
Write-Host "  bash scripts/termux/phone-a/boot-gateway-phone-a.sh"
Write-Host ""
Write-Host "From dev PC: npm run smoke:gateway-prod"
Write-Host "Agents direct (phone-b): npm run smoke:phase8"
Write-Host "Done." -ForegroundColor Green
