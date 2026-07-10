# Package prod api-marketing for phone lab deployment (phase 12).

# Run from phone-lab repo root.

# Builds ../api-marketing on PC — do NOT copy Windows node_modules to phone.



$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "lib\ensure-lf.ps1")

$PhoneLabRoot = Split-Path -Parent $PSScriptRoot

$MarketingRoot = Join-Path (Split-Path -Parent $PhoneLabRoot) "api-marketing"

$Staging = Join-Path $PhoneLabRoot "staging\api-marketing-prod"

$OutTgz = Join-Path $PhoneLabRoot "marketing-prod.tgz"

$TermuxPhoneB = Join-Path $PhoneLabRoot "scripts\termux\phone-b"

$TermuxPhoneA = Join-Path $PhoneLabRoot "scripts\termux\phone-a"



Write-Host "=== Phone Lab: deploy prod api-marketing (phase 12) ===" -ForegroundColor Cyan



if (-not (Test-Path $MarketingRoot)) {

  Write-Error "api-marketing not found at $MarketingRoot"

}



Write-Host "Building api-marketing..."

Push-Location $MarketingRoot

$env:NODE_OPTIONS = "--max-old-space-size=4096"

npm ci --legacy-peer-deps

if ($LASTEXITCODE -ne 0) { Pop-Location; exit $LASTEXITCODE }

npm run build

if ($LASTEXITCODE -ne 0) { Pop-Location; exit $LASTEXITCODE }

Pop-Location

Remove-Item Env:NODE_OPTIONS -ErrorAction SilentlyContinue



$DistMain = Join-Path $MarketingRoot "dist\main.js"

if (-not (Test-Path $DistMain)) {

  Write-Error "Build failed: dist/main.js not found"

}



Write-Host "Staging package..."

if (Test-Path $Staging) { Remove-Item -Recurse -Force $Staging }

New-Item -ItemType Directory -Path $Staging -Force | Out-Null

New-Item -ItemType Directory -Path (Join-Path $Staging "scripts\termux\phone-b") -Force | Out-Null

New-Item -ItemType Directory -Path (Join-Path $Staging "scripts\termux\phone-a") -Force | Out-Null

New-Item -ItemType Directory -Path (Join-Path $Staging "config") -Force | Out-Null



Copy-Item -Recurse (Join-Path $MarketingRoot "dist") (Join-Path $Staging "dist")

Copy-Item (Join-Path $MarketingRoot "package.json") $Staging

Copy-Item (Join-Path $MarketingRoot "package-lock.json") $Staging

Copy-Item (Join-Path $PhoneLabRoot "config\marketing-prod.phone-b.env.example") (Join-Path $Staging ".env.example")

Copy-Item (Join-Path $PhoneLabRoot "config\marketing-prod.phone-*.env.example") (Join-Path $Staging "config")



$phoneBScripts = @(

  "start-redis.sh",

  "install-marketing-deps.sh",

  "setup-marketing-db.sh",

  "start-marketing-prod.sh",

  "restart-marketing-prod.sh",

  "install-boot-marketing.sh"

)

foreach ($name in $phoneBScripts) {

  Copy-Item (Join-Path $TermuxPhoneB $name) (Join-Path $Staging "scripts\termux\phone-b")

}



Copy-Item (Join-Path $TermuxPhoneA "setup-marketing-data-plane.sh") (Join-Path $Staging "scripts\termux\phone-a")

Copy-Item (Join-Path $TermuxPhoneA "install-boot-marketing.sh") (Join-Path $Staging "scripts\termux\phone-a")



# npm install on phone uses full scripts (no ignore-scripts in package .npmrc)



Write-Host "Normalizing .sh line endings (LF)..."

Convert-ShFilesToLf -Directory $Staging



if (Get-Command tar -ErrorAction SilentlyContinue) {

  Push-Location $PhoneLabRoot

  if (Test-Path marketing-prod.tgz) { Remove-Item marketing-prod.tgz }

  tar -czf marketing-prod.tgz -C staging/api-marketing-prod .

  Pop-Location

  Write-Host "Created: $OutTgz"

} else {

  Write-Host "WARN: tar not found"

}



Write-Host ""

Write-Host "From dev PC: npm run deploy:phase12" -ForegroundColor Yellow

Write-Host "Done." -ForegroundColor Green

