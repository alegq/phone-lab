# Phase 12 - deploy api-marketing on phone-b (fallback phone-a) + wire gateway + smoke.
# Run from phone-lab repo root.
# Prerequisites: mesh.env, SSH keys, Phase 9+11 PASS, api-marketing/.env on PC.

param(
    [ValidateSet("phone-b", "phone-a", "auto")]
    [string]$Target = "auto",
    [switch]$SkipSmoke,
    [switch]$SkipBuild,
    [switch]$ForcePhoneA
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

$PhoneLabTemplateOnlyKeys = @(
    'PORT', 'NODE_ENV', 'HEAP_MAX_SIZE',
    'RABBIT_MQ_URI',
    'REDIS_HOST', 'REDIS_PORT', 'REDIS_PASSWORD', 'CACHE_TIME',
    'DB_TYPE', 'DB_HOST', 'DB_PORT', 'DB_USERNAME', 'DB_PASSWORD', 'DB_NAME', 'DB_SYNCHRONIZE'
)

function Merge-MarketingEnvLines([string]$TemplatePath, [hashtable]$SourceVars) {
    $out = New-Object System.Collections.Generic.List[string]
    $seen = @{}
    foreach ($line in Get-Content $TemplatePath) {
        $trim = $line.Trim()
        if (-not $trim -or $trim.StartsWith("#") -or $line.IndexOf("=") -lt 0) {
            $out.Add($line)
            continue
        }
        $eq = $line.IndexOf("=")
        $key = $line.Substring(0, $eq).Trim()
        $seen[$key] = $true
        if ($PhoneLabTemplateOnlyKeys -contains $key) {
            $out.Add($line)
        } elseif ($SourceVars.ContainsKey($key) -and $SourceVars[$key]) {
            $out.Add("$key=$($SourceVars[$key])")
        } else {
            $out.Add($line)
        }
    }
    foreach ($key in $SourceVars.Keys) {
        if (-not $seen.ContainsKey($key) -and $SourceVars[$key]) {
            $out.Add("$key=$($SourceVars[$key])")
        }
    }
    return ,[string[]]$out.ToArray()
}

function Invoke-Ssh([string]$Phone, [string]$Command) {
    python $SshExec $Phone $Command
    return $LASTEXITCODE
}

function Test-MarketingHealth([string]$Phone) {
    $cmd = 'curl -sf -m 15 http://127.0.0.1:4008/api/health/live && curl -sf -m 20 http://127.0.0.1:4008/api/health/ready'
    $code = Invoke-Ssh $Phone $cmd
    return ($code -eq 0)
}

function Deploy-ToPhone([string]$Phone, [string]$TemplateName, [switch]$PhoneAFallback) {
    $marketingTgz = Join-Path $Root "marketing-prod.tgz"
    if (-not (Test-Path -LiteralPath $marketingTgz)) {
        throw "Missing $marketingTgz - run deploy-marketing-prod.ps1"
    }

    Write-Host "Uploading marketing-prod.tgz to $Phone..." -ForegroundColor Cyan
    python $SshUpload $Phone $marketingTgz "~/marketing-prod.tgz"
    if ($LASTEXITCODE -ne 0) { throw "upload failed" }

    Write-Host "Extracting api-marketing on $Phone..."
    Invoke-Ssh $Phone 'mkdir -p ~/phone-lab/packages/api-marketing-prod && cd ~/phone-lab/packages/api-marketing-prod && tar -xzf ~/marketing-prod.tgz' | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "extract failed" }

    Invoke-Ssh $Phone "find ~/phone-lab/packages/api-marketing-prod -name '*.sh' -exec sed -i 's/\r$//' {} +" | Out-Null

    $template = Join-Path $Root "config\$TemplateName"
    $sourceEnv = Join-Path (Split-Path -Parent $Root) "api-marketing\.env"
    $sourceVars = Read-EnvFile $sourceEnv
    if (-not (Test-Path $sourceEnv)) {
        Write-Host "WARN: $sourceEnv not found - using template placeholders only"
    }
    $merged = Merge-MarketingEnvLines $template $sourceVars
    $tempEnv = Join-Path $env:TEMP "phone-lab-marketing-prod-$Phone.env"
    [System.IO.File]::WriteAllLines($tempEnv, [string[]]$merged, (New-Object System.Text.UTF8Encoding $false))
    python $SshUpload $Phone $tempEnv "~/phone-lab-marketing-prod.env"
    if ($LASTEXITCODE -ne 0) { throw "env upload failed" }
    Invoke-Ssh $Phone 'cp -f ~/phone-lab-marketing-prod.env ~/phone-lab/packages/api-marketing-prod/.env && sed -i ''s/\r$//'' ~/phone-lab/packages/api-marketing-prod/.env' | Out-Null
    Remove-Item $tempEnv -ErrorAction SilentlyContinue

    if ($Phone -eq "phone-b") {
        Write-Host "Installing marketing deps on phone-b..."
        Invoke-Ssh $Phone 'bash ~/phone-lab/packages/api-marketing-prod/scripts/termux/phone-b/install-marketing-deps.sh' | Out-Null
        if ($LASTEXITCODE -ne 0) { Write-Host "WARN: install-marketing-deps returned $LASTEXITCODE" }

        Write-Host "Ensuring marketing DB on phone-b..."
        Invoke-Ssh $Phone 'bash ~/phone-lab/packages/api-marketing-prod/scripts/termux/phone-b/setup-marketing-db.sh' | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "setup-marketing-db failed" }
    } else {
        Write-Host "Setting up marketing data plane on phone-a (fallback)..."
        Invoke-Ssh $Phone 'bash ~/phone-lab/packages/api-marketing-prod/scripts/termux/phone-a/setup-marketing-data-plane.sh' | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "setup-marketing-data-plane failed" }
    }

    Write-Host "npm install on $Phone (may take 15-30 min)..."
    Invoke-Ssh $Phone 'cd ~/phone-lab/packages/api-marketing-prod && rm -f .npmrc && npm install --omit=dev --legacy-peer-deps 2>&1 | tail -30' | Out-Null
    $installCode = $LASTEXITCODE

    if ($installCode -ne 0) {
        throw "npm install failed on $Phone (exit $installCode)"
    }

    if ($Phone -eq "phone-b") {
        Write-Host "Installing Termux libvips + Android native bindings..."
        Invoke-Ssh $Phone 'pkg install -y libvips 2>&1 | tail -3' | Out-Null
    }
    Invoke-Ssh $Phone 'cd ~/phone-lab/packages/api-marketing-prod && npm install @napi-rs/canvas-android-arm64 --omit=dev --legacy-peer-deps 2>&1 | tail -5' | Out-Null

    Write-Host "Restarting api-marketing on $Phone..."
    Invoke-Ssh $Phone 'bash ~/phone-lab/packages/api-marketing-prod/scripts/termux/phone-b/restart-marketing-prod.sh' | Out-Null
    Write-Host "Waiting 15s for marketing startup..."
    Start-Sleep -Seconds 15

    $healthy = $false
    for ($i = 1; $i -le 3; $i++) {
        if (Test-MarketingHealth $Phone) {
            $healthy = $true
            break
        }
        Write-Host "Health attempt $i/3 failed; retrying restart..."
        Invoke-Ssh $Phone 'bash ~/phone-lab/packages/api-marketing-prod/scripts/termux/phone-b/restart-marketing-prod.sh' | Out-Null
        Start-Sleep -Seconds 15
    }
    if (-not $healthy) {
        Invoke-Ssh $Phone 'tail -40 ~/phone-lab/logs/marketing-prod.log 2>/dev/null || echo no-log'
        throw "marketing health failed on $Phone after 3 attempts"
    }

    if ($Phone -eq "phone-b") {
        Invoke-Ssh $Phone 'bash ~/phone-lab/packages/api-marketing-prod/scripts/termux/phone-b/install-boot-marketing.sh' | Out-Null
    } else {
        Invoke-Ssh $Phone 'bash ~/phone-lab/packages/api-marketing-prod/scripts/termux/phone-a/install-boot-marketing.sh' | Out-Null
    }
}

function Wire-GatewayMarketing([string]$MarketingIp) {
    $url = "http://${MarketingIp}:4008"
    Write-Host "Wiring gateway MARKETING_INTERNAL_URL=$url on phone-a..." -ForegroundColor Cyan
    $wireCmd =
        'set -euo pipefail; ENVFILE="$HOME/phone-lab/packages/api-gateway-prod/.env"; ' +
        'if grep -q ''^MARKETING_INTERNAL_URL='' "$ENVFILE"; then ' +
        ('sed -i ''s|^MARKETING_INTERNAL_URL=.*|MARKETING_INTERNAL_URL=' + $url + '|'' "$ENVFILE"; ') +
        ('else echo ''MARKETING_INTERNAL_URL=' + $url + ''' >> "$ENVFILE"; fi; ') +
        'grep -n ''^MARKETING_INTERNAL_URL='' "$ENVFILE"'
    Invoke-Ssh "phone-a" $wireCmd | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "gateway wire failed" }

    Write-Host "Restarting gateway on phone-a..."
    Invoke-Ssh "phone-a" 'bash ~/phone-lab/packages/api-gateway-prod/scripts/termux/phone-a/restart-gateway-prod.sh 2>/dev/null || bash ~/phone-lab/scripts/termux/phone-a/restart-gateway-prod.sh' | Out-Null
    Start-Sleep -Seconds 8
}

function Write-MeshMarketingEnv([string]$Phone, [string]$Ip) {
    $path = Join-Path $Root "mesh.marketing.env"
    @(
        "# Written by deploy-phase12.ps1",
        "MARKETING_PHONE=$Phone",
        "MARKETING_IP=$Ip",
        "MARKETING_PORT=4008"
    ) | Set-Content -Path $path -Encoding utf8
    Write-Host "Recorded: $path"
}

Write-Host "=== Phone Lab: deploy phase 12 (api-marketing + gateway proxy) ===" -ForegroundColor Cyan

$mesh = Read-EnvFile (Join-Path $Root "mesh.env")
$phoneBIp = $mesh["PHONE_B_IP"]
if (-not $phoneBIp) { $phoneBIp = "100.103.183.36" }
$phoneAIp = $mesh["PHONE_A_IP"]
if (-not $phoneAIp) { $phoneAIp = "100.120.187.10" }

if (-not $SkipBuild) {
    & (Join-Path $PSScriptRoot "deploy-marketing-prod.ps1")
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

$chosenPhone = $null
$chosenIp = $null
$deployFailed = $false

if ($ForcePhoneA -or $Target -eq "phone-a") {
    Deploy-ToPhone "phone-a" "marketing-prod.phone-a.env.example" -PhoneAFallback
    $chosenPhone = "phone-a"
    $chosenIp = $phoneAIp
} elseif ($Target -eq "phone-b") {
    Deploy-ToPhone "phone-b" "marketing-prod.phone-b.env.example"
    $chosenPhone = "phone-b"
    $chosenIp = $phoneBIp
} else {
    try {
        Write-Host "Auto mode: deploying to phone-b first..." -ForegroundColor Yellow
        Deploy-ToPhone "phone-b" "marketing-prod.phone-b.env.example"
        $chosenPhone = "phone-b"
        $chosenIp = $phoneBIp
    } catch {
        Write-Host "WARN: phone-b deploy failed: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "Falling back to phone-a..." -ForegroundColor Yellow
        $deployFailed = $true
        Deploy-ToPhone "phone-a" "marketing-prod.phone-a.env.example" -PhoneAFallback
        $chosenPhone = "phone-a"
        $chosenIp = $phoneAIp
    }
}

if (-not $chosenPhone) {
    throw "Deploy did not complete on any phone"
}

Write-MeshMarketingEnv $chosenPhone $chosenIp
Wire-GatewayMarketing $chosenIp

Push-Location $Root
try {
    if (-not $SkipSmoke) {
        $env:MARKETING_URL = "http://${chosenIp}:4008"
        npm run smoke:phase12
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

        npm run smoke:phase11
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

        npm run smoke:gateway-prod
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

        npm run smoke:public
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }
} finally {
    Pop-Location
    Remove-Item Env:MARKETING_URL -ErrorAction SilentlyContinue
}

if ($deployFailed) {
    Write-Host "`nPhase 12 complete on phone-a (fallback after phone-b failure)." -ForegroundColor Yellow
} else {
    Write-Host "`nPhase 12 deploy complete on $chosenPhone ($chosenIp)." -ForegroundColor Green
}
