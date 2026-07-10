# Package prod api-content for phone lab deployment (phase 13).
# Run from phone-lab repo root.
# Builds ../api-content on PC — do NOT copy Windows node_modules to phone.

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "lib\ensure-lf.ps1")

$PhoneLabRoot = Split-Path -Parent $PSScriptRoot
$ContentRoot = Join-Path (Split-Path -Parent $PhoneLabRoot) "api-content"
$Staging = Join-Path $PhoneLabRoot "staging\api-content-prod"
$OutTgz = Join-Path $PhoneLabRoot "content-prod.tgz"
$TermuxPhoneB = Join-Path $PhoneLabRoot "scripts\termux\phone-b"
$TermuxPhoneA = Join-Path $PhoneLabRoot "scripts\termux\phone-a"

Write-Host "=== Phone Lab: deploy prod api-content (phase 13) ===" -ForegroundColor Cyan

if (-not (Test-Path $ContentRoot)) {
  Write-Error "api-content not found at $ContentRoot"
}

Write-Host "Building api-content..."
Push-Location $ContentRoot
$env:NODE_OPTIONS = "--max-old-space-size=4096"
npm ci --legacy-peer-deps
if ($LASTEXITCODE -ne 0) { Pop-Location; exit $LASTEXITCODE }
npm run build
if ($LASTEXITCODE -ne 0) { Pop-Location; exit $LASTEXITCODE }
Pop-Location
Remove-Item Env:NODE_OPTIONS -ErrorAction SilentlyContinue

$DistMain = Join-Path $ContentRoot "dist\src\main.js"
if (-not (Test-Path $DistMain)) {
  Write-Error "Build failed: dist/src/main.js not found"
}

Write-Host "Staging package..."
if (Test-Path $Staging) { Remove-Item -Recurse -Force $Staging }
New-Item -ItemType Directory -Path $Staging -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $Staging "scripts\termux\phone-b") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $Staging "scripts\termux\phone-a") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $Staging "config") -Force | Out-Null

Copy-Item -Recurse (Join-Path $ContentRoot "dist") (Join-Path $Staging "dist")
Copy-Item (Join-Path $ContentRoot "package.json") $Staging
Copy-Item (Join-Path $ContentRoot "package-lock.json") $Staging
Copy-Item (Join-Path $PhoneLabRoot "config\content-prod.phone-*.env.example") (Join-Path $Staging "config")

$contentScripts = @(
  "setup-content-db.sh",
  "start-content-prod.sh",
  "restart-content-prod.sh",
  "install-boot-content.sh"
)
foreach ($name in $contentScripts) {
  Copy-Item (Join-Path $TermuxPhoneB $name) (Join-Path $Staging "scripts\termux\phone-b")
}

Copy-Item (Join-Path $TermuxPhoneA "setup-content-data-plane.sh") (Join-Path $Staging "scripts\termux\phone-a")
Copy-Item (Join-Path $TermuxPhoneA "install-boot-content.sh") (Join-Path $Staging "scripts\termux\phone-a")

Copy-Item (Join-Path $PhoneLabRoot "config\content-prod.phone-b.env.example") (Join-Path $Staging ".env.example")

Set-Content -Path (Join-Path $Staging ".npmrc") -Value "ignore-scripts=true`n" -NoNewline

Write-Host "Normalizing .sh line endings (LF)..."
Convert-ShFilesToLf -Directory $Staging

if (Get-Command tar -ErrorAction SilentlyContinue) {
  Push-Location $PhoneLabRoot
  if (Test-Path content-prod.tgz) { Remove-Item content-prod.tgz }
  tar -czf content-prod.tgz -C staging/api-content-prod .
  Pop-Location
  Write-Host "Created: $OutTgz"
} else {
  Write-Host "WARN: tar not found"
}

Write-Host ""
Write-Host "From dev PC: npm run deploy:phase13" -ForegroundColor Yellow
Write-Host "Done." -ForegroundColor Green
