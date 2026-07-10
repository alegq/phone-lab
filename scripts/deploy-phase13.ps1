# Phase 13 - deploy full api-content on phone-b (fallback phone-a) + migrate DB + smoke.
# Run from phone-lab repo root.
# Prerequisites: mesh.env, mesh.secrets.env, SSH keys, api-content/.env on PC.

param(
    [ValidateSet("phone-b", "phone-a", "auto")]
    [string]$Target = "auto",
    [switch]$SkipSmoke,
    [switch]$SkipBuild,
    [switch]$SkipMigrate,
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
    'DB_TYPE', 'DB_HOST', 'DB_PORT', 'DB_USERNAME', 'DB_PASSWORD', 'DB_NAME', 'DB_SYNCHRONIZE',
    'BLOG_UPSCALE_ENABLED', 'SEED_TEMPLATE_BUILDER', 'SEED_BLOGS', 'BLOG_ASSET_RETENTION_DAYS',
    'GATEWAY_PUBLIC_URL', 'BLOG_PUBLIC_BASE_URL',
    'AUTH_URI', 'TOKEN_URI', 'AUTH_PROVIDER_X509_CERT_URL', 'BUCKET'
)

function Merge-ContentEnvLines([string]$TemplatePath, [hashtable]$SourceVars, [hashtable]$Secrets) {
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
        if ($key -eq "INTERNAL_SERVICE_TOKEN" -and $Secrets["INTERNAL_SERVICE_TOKEN"]) {
            $out.Add("INTERNAL_SERVICE_TOKEN=$($Secrets['INTERNAL_SERVICE_TOKEN'])")
        } elseif ($key -eq "GEMINI_API_KEY" -and $Secrets["GEMINI_API_KEY"]) {
            $out.Add("GEMINI_API_KEY=$($Secrets['GEMINI_API_KEY'])")
        } elseif ($key -eq "JWT_SECRET") {
            $val = if ($SourceVars["JWT_SECRET"]) { $SourceVars["JWT_SECRET"] } else { $line.Substring($eq + 1).Trim() }
            $out.Add("JWT_SECRET=$val")
        } elseif ($PhoneLabTemplateOnlyKeys -contains $key) {
            $out.Add($line)
        } elseif ($SourceVars.ContainsKey($key) -and $SourceVars[$key]) {
            $out.Add("$key=$($SourceVars[$key])")
        } else {
            $out.Add($line)
        }
    }
    foreach ($key in $SourceVars.Keys) {
        if (-not $seen.ContainsKey($key) -and $SourceVars[$key] -and ($PhoneLabTemplateOnlyKeys -notcontains $key)) {
            $out.Add("$key=$($SourceVars[$key])")
        }
    }
    return ,[string[]]$out.ToArray()
}

function Invoke-Ssh([string]$Phone, [string]$Command) {
    python $SshExec $Phone $Command
    return $LASTEXITCODE
}

function Test-ContentHealth([string]$Phone) {
    $cmd = 'curl -sf -m 15 http://127.0.0.1:4004/public/api/content/health/live && curl -sf -m 30 http://127.0.0.1:4004/public/api/content/health/ready'
    $code = Invoke-Ssh $Phone $cmd
    return ($code -eq 0)
}

function Wire-GatewayContent([string]$ContentIp, [string]$ContentPhone) {
    # Gateway and content on the same phone: loopback avoids stale Tailscale routing.
    $wireIp = if ($ContentPhone -eq "phone-a") { "127.0.0.1" } else { $ContentIp }
    $url = "http://${wireIp}:4004"
    Write-Host "Wiring gateway CONTENT_INTERNAL_URL=$url on phone-a..." -ForegroundColor Cyan
    $wireCmd =
        'set -euo pipefail; ENVFILE="$HOME/phone-lab/packages/api-gateway-prod/.env"; ' +
        'if grep -q ''^CONTENT_INTERNAL_URL='' "$ENVFILE"; then ' +
        ('sed -i ''s|^CONTENT_INTERNAL_URL=.*|CONTENT_INTERNAL_URL=' + $url + '|'' "$ENVFILE"; ') +
        ('else echo ''CONTENT_INTERNAL_URL=' + $url + ''' >> "$ENVFILE"; fi; ') +
        'grep -n ''^CONTENT_INTERNAL_URL='' "$ENVFILE"'
    Invoke-Ssh "phone-a" $wireCmd | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "gateway CONTENT wire failed" }

    Write-Host "Restarting gateway on phone-a..."
    Invoke-Ssh "phone-a" 'bash ~/phone-lab/packages/api-gateway-prod/scripts/termux/phone-a/restart-gateway-prod.sh 2>/dev/null || bash ~/phone-lab/scripts/termux/phone-a/restart-gateway-prod.sh' | Out-Null
    Start-Sleep -Seconds 8
}

function Wire-AgentsContent([string]$ContentIp) {
    $url = "http://${ContentIp}:4004"
    Write-Host "Wiring phone-b agents CONTENT_INTERNAL_URL=$url..." -ForegroundColor Cyan
    $wireCmd =
        'set -euo pipefail; ENVFILE="$HOME/phone-lab/packages/api-agents-prod/.env"; ' +
        'if [ ! -f "$ENVFILE" ]; then echo "missing agents .env"; exit 1; fi; ' +
        ('if grep -q ''^CONTENT_INTERNAL_URL='' "$ENVFILE"; then sed -i ''s|^CONTENT_INTERNAL_URL=.*|CONTENT_INTERNAL_URL=' + $url + '|'' "$ENVFILE"; else echo ''CONTENT_INTERNAL_URL=' + $url + ''' >> "$ENVFILE"; fi')
    Invoke-Ssh "phone-b" $wireCmd | Out-Null
    if ($LASTEXITCODE -ne 0) { Write-Host "WARN: agents CONTENT wire failed" }
}

function Write-MeshContentEnv([string]$Phone, [string]$Ip) {
    $path = Join-Path $Root "mesh.content.env"
    $lines = @(
        "# Written by deploy-phase13.ps1",
        "CONTENT_PHONE=$Phone",
        "CONTENT_IP=$Ip",
        "CONTENT_PORT=4004"
    )
    $lines | Set-Content -Path $path -Encoding utf8
    Write-Host "Recorded: $path"

    $tempPath = Join-Path $env:TEMP "phone-lab-mesh.content.env"
    $lines | Set-Content -Path $tempPath -Encoding utf8
    python $SshUpload phone-b $tempPath "~/phone-lab/mesh.content.env"
    if ($LASTEXITCODE -ne 0) { Write-Host "WARN: mesh.content.env upload to phone-b failed" }
    Remove-Item $tempPath -ErrorAction SilentlyContinue
}

function Deploy-ToPhone([string]$Phone, [string]$TemplateName) {
    $contentTgz = Join-Path $Root "content-prod.tgz"
    $agentsTgz = Join-Path $Root "agents-prod.tgz"
    if (-not (Test-Path -LiteralPath $contentTgz)) {
        throw "Missing $contentTgz - run deploy-content-prod.ps1"
    }

    Write-Host "Uploading content-prod.tgz to $Phone..." -ForegroundColor Cyan
    python $SshUpload $Phone $contentTgz "~/content-prod.tgz"
    if ($LASTEXITCODE -ne 0) { throw "content upload failed" }

    if ($Phone -eq "phone-b" -and (Test-Path $agentsTgz)) {
        Write-Host "Uploading agents-prod.tgz (boot stack) to phone-b..."
        python $SshUpload phone-b $agentsTgz "~/agents-prod.tgz"
        if ($LASTEXITCODE -ne 0) { throw "agents upload failed" }
        Invoke-Ssh phone-b 'mkdir -p ~/phone-lab/packages/api-agents-prod && cd ~/phone-lab/packages/api-agents-prod && tar -xzf ~/agents-prod.tgz' | Out-Null
        Invoke-Ssh phone-b "find ~/phone-lab/packages/api-agents-prod -name '*.sh' -exec sed -i 's/\r$//' {} +" | Out-Null
    }

    Write-Host "Extracting api-content-prod on $Phone..."
    Invoke-Ssh $Phone 'mkdir -p ~/phone-lab/packages/api-content-prod && cd ~/phone-lab/packages/api-content-prod && tar -xzf ~/content-prod.tgz' | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "content extract failed" }

    Invoke-Ssh $Phone "find ~/phone-lab/packages/api-content-prod -name '*.sh' -exec sed -i 's/\r$//' {} +" | Out-Null

    $template = Join-Path $Root "config\$TemplateName"
    $sourceEnv = Join-Path (Split-Path -Parent $Root) "api-content\.env"
    $sourceVars = Read-EnvFile $sourceEnv
    if (-not (Test-Path $sourceEnv)) {
        Write-Host "WARN: $sourceEnv not found - using template placeholders for GCS secrets"
    }
    $merged = Merge-ContentEnvLines $template $sourceVars $script:Secrets
    $tempEnv = Join-Path $env:TEMP "phone-lab-content-prod-$Phone.env"
    [System.IO.File]::WriteAllLines($tempEnv, [string[]]$merged, (New-Object System.Text.UTF8Encoding $false))
    python $SshUpload $Phone $tempEnv "~/phone-lab-content-prod.env"
    if ($LASTEXITCODE -ne 0) { throw "env upload failed" }
    Invoke-Ssh $Phone 'cp -f ~/phone-lab-content-prod.env ~/phone-lab/packages/api-content-prod/.env && sed -i ''s/\r$//'' ~/phone-lab/packages/api-content-prod/.env' | Out-Null
    Remove-Item $tempEnv -ErrorAction SilentlyContinue

    if ($Phone -eq "phone-b") {
        Write-Host "Ensuring content DB on phone-b..."
        Invoke-Ssh $Phone 'bash ~/phone-lab/packages/api-content-prod/scripts/termux/phone-b/setup-content-db.sh' | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "setup-content-db failed" }
    } else {
        Write-Host "Setting up content data plane on phone-a..."
        Invoke-Ssh $Phone 'bash ~/phone-lab/packages/api-content-prod/scripts/termux/phone-a/setup-content-data-plane.sh' | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "setup-content-data-plane failed" }
    }

    if (-not $script:SkipMigrate) {
        & (Join-Path $PSScriptRoot "migrate-content-db.ps1") -Phone $Phone
        if ($LASTEXITCODE -ne 0) { throw "migrate-content-db failed" }
    } else {
        Write-Host "Skipping DB migration (-SkipMigrate)"
    }

    Write-Host "npm install on $Phone (may take 15-30 min)..."
    Invoke-Ssh $Phone 'cd ~/phone-lab/packages/api-content-prod && PUPPETEER_SKIP_DOWNLOAD=true npm install --omit=dev --legacy-peer-deps --ignore-scripts 2>&1 | tail -40' | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "npm install failed on $Phone" }

    Write-Host "Installing Termux libvips + sharp for Android ARM64..."
    Invoke-Ssh $Phone 'pkg install -y libvips 2>&1 | tail -3' | Out-Null
    Invoke-Ssh $Phone 'cd ~/phone-lab/packages/api-content-prod && rm -rf node_modules/sharp && npm install sharp --platform=android --arch=arm64v8 --omit=dev --legacy-peer-deps 2>&1 | tail -15' | Out-Host

    if ($Phone -eq "phone-b") {
        Invoke-Ssh phone-b 'pkill -f api-content-prod 2>/dev/null || true'
    } else {
        Invoke-Ssh phone-b 'pkill -f api-content-prod 2>/dev/null || true' | Out-Null
    }

    Write-Host "Starting api-content-prod on $Phone..."
    Invoke-Ssh $Phone 'bash ~/phone-lab/packages/api-content-prod/scripts/termux/phone-b/restart-content-prod.sh' | Out-Null
    Write-Host "Waiting 45s for content startup (RabbitMQ + GCS)..."
    Start-Sleep -Seconds 45

    $healthy = $false
    for ($i = 1; $i -le 5; $i++) {
        if (Test-ContentHealth $Phone) {
            $healthy = $true
            break
        }
        if ($i -eq 1) {
            Invoke-Ssh $Phone 'pgrep -af api-content-prod || true; curl -s -m 5 http://127.0.0.1:4004/public/api/content/health/live || true' | Out-Host
        }
        Write-Host "Health attempt $i/5 failed on $Phone; waiting..."
        Start-Sleep -Seconds 15
    }
    if (-not $healthy) {
        Invoke-Ssh $Phone 'tail -50 ~/phone-lab/logs/content-prod.log 2>/dev/null || echo no-log' | Out-Host
        throw "content health failed on $Phone after 5 attempts"
    }

    if ($Phone -eq "phone-b") {
        Invoke-Ssh $Phone 'bash ~/phone-lab/packages/api-content-prod/scripts/termux/phone-b/install-boot-content.sh' | Out-Null
    } else {
        Invoke-Ssh $Phone 'bash ~/phone-lab/packages/api-content-prod/scripts/termux/phone-a/install-boot-content.sh' | Out-Null
    }
}

Write-Host "=== Phone Lab: deploy phase 13 (api-content-prod) ===" -ForegroundColor Cyan

$mesh = Read-EnvFile (Join-Path $Root "mesh.env")
$phoneBIp = $mesh["PHONE_B_IP"]
if (-not $phoneBIp) { $phoneBIp = "100.103.183.36" }
$phoneAIp = $mesh["PHONE_A_IP"]
if (-not $phoneAIp) { $phoneAIp = "100.120.187.10" }

$secretsFile = Join-Path $Root "mesh.secrets.env"
$script:Secrets = Read-EnvFile $secretsFile
if (-not $script:Secrets["INTERNAL_SERVICE_TOKEN"]) {
    $script:Secrets["INTERNAL_SERVICE_TOKEN"] = "phone-lab-internal-token"
}
$script:SkipMigrate = $SkipMigrate

if (-not $SkipBuild) {
    & (Join-Path $PSScriptRoot "deploy-content-prod.ps1")
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    & (Join-Path $PSScriptRoot "deploy-agents-prod.ps1")
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

$chosenPhone = $null
$chosenIp = $null
$deployFailed = $false

if ($ForcePhoneA -or $Target -eq "phone-a") {
    Deploy-ToPhone "phone-a" "content-prod.phone-a.env.example"
    $chosenPhone = "phone-a"
    $chosenIp = $phoneAIp
} elseif ($Target -eq "phone-b") {
    Deploy-ToPhone "phone-b" "content-prod.phone-b.env.example"
    $chosenPhone = "phone-b"
    $chosenIp = $phoneBIp
} else {
    try {
        Write-Host "Auto mode: deploying to phone-b first..." -ForegroundColor Yellow
        Deploy-ToPhone "phone-b" "content-prod.phone-b.env.example"
        $chosenPhone = "phone-b"
        $chosenIp = $phoneBIp
    } catch {
        Write-Host "WARN: phone-b deploy failed: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "Falling back to phone-a..." -ForegroundColor Yellow
        $deployFailed = $true
        Invoke-Ssh phone-b 'pkill -f api-content-prod 2>/dev/null || true; rm -rf ~/phone-lab/packages/api-content-prod' | Out-Null
        Deploy-ToPhone "phone-a" "content-prod.phone-a.env.example"
        $chosenPhone = "phone-a"
        $chosenIp = $phoneAIp
    }
}

if (-not $chosenPhone) {
    throw "Deploy did not complete on any phone"
}

Write-MeshContentEnv $chosenPhone $chosenIp
Wire-GatewayContent $chosenIp $chosenPhone

Write-Host "Syncing INTERNAL_SERVICE_TOKEN to agents..."
& (Join-Path $PSScriptRoot "apply-phone-b-env.ps1") -Profile live
if ($LASTEXITCODE -ne 0) { Write-Host "WARN: apply-phone-b-env returned $LASTEXITCODE" }

if ($chosenPhone -eq "phone-a") {
    Wire-AgentsContent $chosenIp
} else {
    Wire-AgentsContent "127.0.0.1"
}

if ($chosenPhone -eq "phone-b") {
    Write-Host "Restarting boot stack on phone-b..."
    Invoke-Ssh phone-b 'bash ~/phone-lab/packages/api-agents-prod/scripts/termux/phone-b/boot-stack-phone-b.sh' | Out-Null
    Start-Sleep -Seconds 30
} else {
    Write-Host "Restarting agents on phone-b (content on phone-a)..."
    Invoke-Ssh phone-b 'bash ~/phone-lab/packages/api-agents-prod/scripts/termux/phone-b/restart-agents-prod.sh' | Out-Null
    Start-Sleep -Seconds 15
}

if (-not (Test-ContentHealth $chosenPhone)) {
    Write-Host "WARN: content health check failed after wiring"
}

Push-Location $Root
try {
    if (-not $SkipSmoke) {
        $env:CONTENT_URL = "http://${chosenIp}:4004"
        npm run smoke:phase13
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

        npm run smoke:phase12
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

        npm run smoke:phase11
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }
} finally {
    Pop-Location
    Remove-Item Env:CONTENT_URL -ErrorAction SilentlyContinue
}

if ($deployFailed) {
    Write-Host "`nPhase 13 complete on phone-a (fallback after phone-b failure)." -ForegroundColor Yellow
} else {
    Write-Host "`nPhase 13 deploy complete on $chosenPhone ($chosenIp)." -ForegroundColor Green
}
