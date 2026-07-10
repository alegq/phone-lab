# Phase 14 — deploy OpenClaw Termux scripts + env templates to phone-a.
# Run from phone-lab repo root.
# Prerequisites: mesh.env, SSH keys (npm run remote:setup).
# OpenClaw binary install remains upstream on device (openclaw onboard).

param(
    [switch]$SkipInstallBoot,
    [switch]$SkipSmoke
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "lib\ensure-lf.ps1")

$Root = Split-Path -Parent $PSScriptRoot
$SshExec = Join-Path $PSScriptRoot "remote\ssh_exec.py"
$SshUpload = Join-Path $PSScriptRoot "remote\ssh_upload.py"
$TermuxPhoneA = Join-Path $Root "scripts\termux\phone-a"

Write-Host "=== Phone Lab: deploy Phase 14 (OpenClaw phone-a scripts) ===" -ForegroundColor Cyan

$OpenClawScripts = @(
    "openclaw-env.sh",
    "start-openclaw-phone-a.sh",
    "restart-openclaw-phone-a.sh",
    "boot-openclaw-phone-a.sh",
    "install-boot-openclaw.sh",
    "install-openclaw-proot.sh",
    "verify-openclaw-phone-a.sh"
)

Convert-ShFilesToLf -Directory $TermuxPhoneA

function Invoke-Ssh([string]$Phone, [string]$Command) {
    python $SshExec $Phone $Command
    return $LASTEXITCODE
}

function Upload-OpenClawScripts {
    Write-Host "Uploading OpenClaw scripts to phone-a..." -ForegroundColor Cyan
    Invoke-Ssh "phone-a" "mkdir -p ~/phone-lab/scripts/termux/phone-a ~/phone-lab/config ~/phone-lab/logs ~/openclaw-workspace" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "mkdir failed on phone-a" }

    foreach ($name in $OpenClawScripts) {
        $localPath = Join-Path $TermuxPhoneA $name
        if (-not (Test-Path $localPath)) { throw "Missing $localPath" }
        $remotePath = "~/phone-lab/scripts/termux/phone-a/$name"
        python $SshUpload "phone-a" $localPath $remotePath
        if ($LASTEXITCODE -ne 0) { throw "upload failed: $name" }
    }

    $envExample = Join-Path $Root "config\openclaw-phone-a.env.example"
    if (Test-Path $envExample) {
        python $SshUpload "phone-a" $envExample "~/phone-lab/config/openclaw-phone-a.env.example"
        if ($LASTEXITCODE -ne 0) { Write-Host "WARN: env example upload failed" -ForegroundColor Yellow }
    }

    $wsReadme = Join-Path $Root "openclaw-workspace\README.md"
    if (Test-Path $wsReadme) {
        python $SshUpload "phone-a" $wsReadme "~/openclaw-workspace/README.md"
    }
    $wsSoul = Join-Path $Root "openclaw-workspace\SOUL.md"
    if (Test-Path $wsSoul) {
        python $SshUpload "phone-a" $wsSoul "~/openclaw-workspace/SOUL.md"
    }

    Invoke-Ssh "phone-a" "find ~/phone-lab/scripts/termux/phone-a -name '*openclaw*' -exec chmod +x {} + ; find ~/phone-lab/scripts/termux/phone-a -name '*openclaw*' -exec sed -i 's/\r$//' {} +" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "chmod failed on phone-a" }
}

Upload-OpenClawScripts

if (-not $SkipInstallBoot) {
    Write-Host "Installing Termux:Boot entry (optional — requires openclaw onboard first)..."
    Invoke-Ssh "phone-a" "bash ~/phone-lab/scripts/termux/phone-a/install-boot-openclaw.sh" | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "WARN: install-boot-openclaw failed (OK if openclaw not installed yet)" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "Scripts deployed. On phone-a (Termux):" -ForegroundColor Green
Write-Host "  npm install -g openclaw@latest && openclaw onboard"
Write-Host "  bash ~/phone-lab/scripts/termux/phone-a/start-openclaw-phone-a.sh"
Write-Host "  bash ~/phone-lab/scripts/termux/phone-a/verify-openclaw-phone-a.sh"
Write-Host ""
Write-Host "On dev PC: copy mesh.openclaw.env.example -> mesh.openclaw.env, set OPENCLAW_ENABLED=1"
Write-Host "  npm run smoke:phase14"

if (-not $SkipSmoke) {
    $meshOpenclaw = Join-Path $Root "mesh.openclaw.env"
    if (Test-Path $meshOpenclaw) {
        $content = Get-Content $meshOpenclaw -Raw
        if ($content -match 'OPENCLAW_ENABLED=1') {
            Write-Host ""
            Write-Host "Running smoke:phase14..."
            Push-Location $Root
            npm run smoke:phase14
            $smokeCode = $LASTEXITCODE
            Pop-Location
            if ($smokeCode -ne 0) {
                Write-Host "WARN: smoke:phase14 failed — complete openclaw onboard on phone-a first" -ForegroundColor Yellow
            }
        } else {
            Write-Host "Skip smoke (OPENCLAW_ENABLED!=1 in mesh.openclaw.env)" -ForegroundColor Yellow
        }
    } else {
        Write-Host "Skip smoke (mesh.openclaw.env not found)" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "Phase 14 script deploy complete." -ForegroundColor Green
