# Phase 11 — deploy api-auth on phone-b + wire gateway env + verify admin via gateway.
# Run from phone-lab repo root.
#
# Prerequisites: mesh.env, SSH keys (npm run remote:setup), Phase 9 gateway already deployed on phone-a.

param(
    [switch]$SkipSmoke,
    [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$SshExec = Join-Path $PSScriptRoot "remote\ssh_exec.py"
$SshUpload = Join-Path $PSScriptRoot "remote\ssh_upload.py"

function Read-EnvFile([string]$Path) {
    $vars = @{}
    if (-not (Test-Path $Path)) { return $vars }
    Get-Content $Path | ForEach-Object {
        $line = $_.Trim()
        if (-not $line -or $line.StartsWith("#")) { return }
        $eq = $line.IndexOf("=")
        if ($eq -lt 0) { return }
        $key = $line.Substring(0, $eq).Trim()
        $value = $line.Substring($eq + 1).Trim()
        $vars[$key] = $value
    }
    return $vars
}

Write-Host "=== Phone Lab: deploy phase 11 (api-auth + gateway admin) ===" -ForegroundColor Cyan

# Source Firebase key from api-auth/.env (user-approved for lab).
$AuthRepoEnv = Join-Path (Split-Path -Parent $Root) "api-auth\.env"
$authRepoVars = Read-EnvFile $AuthRepoEnv
$firebaseKey = $authRepoVars["FIREBASE_API_KEY"]
if (-not $firebaseKey) {
    Write-Error "FIREBASE_API_KEY not found in $AuthRepoEnv"
}

if (-not $SkipBuild) {
    & (Join-Path $PSScriptRoot "deploy-auth-prod.ps1")
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

$authTgz = Join-Path $Root "auth-prod.tgz"
if (-not (Test-Path $authTgz)) { Write-Error "Missing $authTgz — run deploy-auth-prod.ps1" }

Write-Host "Uploading auth-prod.tgz to phone-b..."
python $SshUpload phone-b $authTgz "~/auth-prod.tgz"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "Extracting auth-prod on phone-b..."
python $SshExec phone-b 'mkdir -p ~/phone-lab/packages/api-auth-prod && cd ~/phone-lab/packages/api-auth-prod && tar -xzf ~/auth-prod.tgz'
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "Writing api-auth .env on phone-b (inject FIREBASE_API_KEY)..."
$authTemplate = Join-Path $Root "config\auth-prod.phone-b.env.example"
$lines = Get-Content $authTemplate
$out = New-Object System.Collections.Generic.List[string]
foreach ($line in $lines) {
    if ($line -match "^FIREBASE_API_KEY=") {
        $out.Add("FIREBASE_API_KEY=$firebaseKey")
        continue
    }
    $out.Add($line)
}
$tempAuthEnv = Join-Path $env:TEMP "phone-lab-auth-prod.env"
[System.IO.File]::WriteAllLines($tempAuthEnv, $out.ToArray(), (New-Object System.Text.UTF8Encoding $false))
python $SshUpload phone-b $tempAuthEnv "~/phone-lab-auth-prod.env"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
python $SshExec phone-b "cp -f ~/phone-lab-auth-prod.env ~/phone-lab/packages/api-auth-prod/.env"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
python $SshExec phone-b "sed -i 's/\r$//' ~/phone-lab/packages/api-auth-prod/.env"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "npm install on phone-b for api-auth (may take 10-20 min)..."
python $SshExec phone-b 'cd ~/phone-lab/packages/api-auth-prod && PUPPETEER_SKIP_DOWNLOAD=true npm install --omit=dev --legacy-peer-deps --ignore-scripts'
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "Ensuring auth DB exists on phone-b..."
python $SshExec phone-b "bash ~/phone-lab/packages/api-auth-prod/scripts/termux/phone-b/setup-auth-db.sh"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "Configuring Rabbit for cross-phone AMQP (phone-b)..."
python $SshExec phone-b "bash ~/phone-lab/packages/api-agents-prod/scripts/termux/phone-b/configure-rabbit-tailscale.sh"
if ($LASTEXITCODE -ne 0) { Write-Host "WARN: configure-rabbit-tailscale returned $LASTEXITCODE" }

Write-Host "Restarting auth on phone-b..."
python $SshExec phone-b "bash ~/phone-lab/packages/api-auth-prod/scripts/termux/phone-b/restart-auth-prod.sh"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "Wiring gateway FIREBASE_API_KEY on phone-a..."
$wireGatewayCmd =
  'set -euo pipefail; ENVFILE="$HOME/phone-lab/packages/api-gateway-prod/.env"; ' +
  'if grep -q ''^FIREBASE_API_KEY='' "$ENVFILE"; then ' +
  ('sed -i ''s/^FIREBASE_API_KEY=.*/FIREBASE_API_KEY=' + $firebaseKey + '/'' "$ENVFILE"; ') +
  ('else echo ''FIREBASE_API_KEY=' + $firebaseKey + ''' >> "$ENVFILE"; fi; ') +
  'grep -n ''^FIREBASE_API_KEY='' "$ENVFILE"'
python $SshExec phone-a $wireGatewayCmd
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "Restarting gateway on phone-a..."
python $SshExec phone-a 'bash ~/phone-lab/packages/api-gateway-prod/scripts/termux/phone-a/start-gateway-prod.sh || true'

Write-Host "Verifying phone-a can reach phone-b AMQP..."
python $SshExec phone-a "timeout 5 bash -lc 'echo > /dev/tcp/100.103.183.36/5672'"
if ($LASTEXITCODE -ne 0) { Write-Error "phone-a cannot reach phone-b:5672 (AMQP) — Phase 11 cannot work" }

Write-Host "Ensuring Firebase admin user exists (dev PC)..."
$env:FIREBASE_API_KEY = $firebaseKey
$uid = node (Join-Path $Root "scripts\phase11-ensure-firebase-admin.mjs") 2>$null
Remove-Item Env:FIREBASE_API_KEY -ErrorAction SilentlyContinue
if (-not $uid) { Write-Error "Failed to ensure Firebase admin user. Check FIREBASE_API_KEY and credentials." }

Write-Host "Seeding admin row into auth DB (phone-b)..."
$seedSql = @"
INSERT INTO \"admins\" (\"id\",\"firstName\",\"lastName\",\"role\",\"canAccessMarketing\",\"isAbleManageAdmins\",\"isAbleManageClients\",\"isAbleManageUsers\")
VALUES ('$uid','Local','Admin','super_admin',false,true,true,true)
ON CONFLICT (\"id\") DO NOTHING;
"@
$seedSqlOneLine = ($seedSql -replace "`r?`n", " ").Trim()

$seedSqlEsc = $seedSqlOneLine.Replace('"', '\"')
$seedCmd = 'psql -U admin -d auth -c "' + $seedSqlEsc + '"'
python $SshExec phone-b $seedCmd
if ($LASTEXITCODE -ne 0) {
    Write-Host "WARN: seed insert failed (table may not exist yet). Retrying after 10s..."
    Start-Sleep -Seconds 10
    python $SshExec phone-b $seedCmd
    if ($LASTEXITCODE -ne 0) { Write-Host "WARN: seed insert still failing; continuing (you may need to seed manually)." }
}

Write-Host "Waiting 10s..."
Start-Sleep -Seconds 10

Push-Location $Root
try {
    npm run smoke:gateway-prod
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    npm run smoke:phase8
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    if (-not $SkipSmoke) {
        npm run smoke:phase11
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }
} finally {
    Pop-Location
    if ($tempAuthEnv) { Remove-Item $tempAuthEnv -ErrorAction SilentlyContinue }
}

Write-Host "`nPhase 11 deploy complete." -ForegroundColor Green
