# Deploy Phone Lab watchdog scripts to phone-a and phone-b + install cron.
# Run from phone-lab repo root.
# Prerequisites: mesh.env, SSH keys (npm run remote:setup).

param(
    [ValidateSet("phone-a", "phone-b", "both")]
    [string]$Target = "both",
    [switch]$SkipInstall
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "lib\ensure-lf.ps1")

$Root = Split-Path -Parent $PSScriptRoot
$SshExec = Join-Path $PSScriptRoot "remote\ssh_exec.py"
$SshUpload = Join-Path $PSScriptRoot "remote\ssh_upload.py"
$TermuxRoot = Join-Path $Root "scripts\termux"

Write-Host "=== Phone Lab: deploy watchdog (Termux cron) ===" -ForegroundColor Cyan

$WatchdogFiles = @(
    @{ Local = "lib\watchdog-lib.sh"; RemoteDir = "lib" },
    @{ Local = "lib\kill-service-by-cwd.sh"; RemoteDir = "lib" },
    @{ Local = "phone-b\watch-stack-phone-b.sh"; RemoteDir = "phone-b" },
    @{ Local = "phone-b\install-watchdog-cron.sh"; RemoteDir = "phone-b" },
    @{ Local = "phone-a\watch-stack-phone-a.sh"; RemoteDir = "phone-a" },
    @{ Local = "phone-a\install-watchdog-cron.sh"; RemoteDir = "phone-a" },
    @{ Local = "phone-a\openclaw-env.sh"; RemoteDir = "phone-a" },
    @{ Local = "phone-a\restart-openclaw-phone-a.sh"; RemoteDir = "phone-a" }
)

Write-Host "Normalizing .sh line endings (LF)..."
Convert-ShFilesToLf -Directory (Join-Path $TermuxRoot "lib")
Convert-ShFilesToLf -Directory (Join-Path $TermuxRoot "phone-a")
Convert-ShFilesToLf -Directory (Join-Path $TermuxRoot "phone-b")

function Invoke-Ssh([string]$Phone, [string]$Command) {
    python $SshExec $Phone $Command
    return $LASTEXITCODE
}

function Upload-MeshEnvFiles([string]$Phone) {
    foreach ($name in @("mesh.content.env", "mesh.marketing.env")) {
        $localPath = Join-Path $Root $name
        if (Test-Path $localPath) {
            python $SshUpload $Phone $localPath "~/phone-lab/$name"
            if ($LASTEXITCODE -ne 0) {
                Write-Host "WARN: upload $name to $Phone failed" -ForegroundColor Yellow
            }
        }
    }
}

function Upload-WatchdogFiles([string]$Phone) {
    Write-Host "Uploading watchdog scripts to $Phone..." -ForegroundColor Cyan
    Invoke-Ssh $Phone "mkdir -p ~/phone-lab/scripts/termux/lib ~/phone-lab/scripts/termux/phone-a ~/phone-lab/scripts/termux/phone-b" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "mkdir failed on $Phone" }

    foreach ($item in $WatchdogFiles) {
        $localPath = Join-Path $TermuxRoot $item.Local
        if (-not (Test-Path $localPath)) {
            throw "Missing $localPath"
        }
        $remotePath = "~/phone-lab/scripts/termux/$($item.RemoteDir)/$(Split-Path -Leaf $localPath)"
        python $SshUpload $Phone $localPath $remotePath
        if ($LASTEXITCODE -ne 0) { throw "upload failed: $($item.Local) -> $Phone" }
    }

    Invoke-Ssh $Phone "find ~/phone-lab/scripts/termux -name '*.sh' -exec chmod +x {} + ; find ~/phone-lab/scripts/termux -name '*.sh' -exec sed -i 's/\r$//' {} +" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "chmod/sed failed on $Phone" }
}

function Install-Watchdog([string]$Phone) {
    if ($Phone -eq "phone-b") {
        $installScript = "~/phone-lab/scripts/termux/phone-b/install-watchdog-cron.sh"
        $watchScript = "~/phone-lab/scripts/termux/phone-b/watch-stack-phone-b.sh"
    } else {
        $installScript = "~/phone-lab/scripts/termux/phone-a/install-watchdog-cron.sh"
        $watchScript = "~/phone-lab/scripts/termux/phone-a/watch-stack-phone-a.sh"
    }

    if (-not $SkipInstall) {
        Write-Host "Installing cron on $Phone..."
        Invoke-Ssh $Phone "bash $installScript"
        if ($LASTEXITCODE -ne 0) { throw "install-watchdog-cron failed on $Phone" }
    }

    Write-Host "Running watchdog once on $Phone..."
    Invoke-Ssh $Phone "timeout 180 bash $watchScript"
    $watchCode = $LASTEXITCODE
    if ($watchCode -ne 0) {
        Write-Host "WARN: watchdog returned $watchCode on $Phone (some services may be down)" -ForegroundColor Yellow
    }

    Write-Host "Recent watchdog log on ${Phone}:"
    Invoke-Ssh $Phone "tail -15 ~/phone-lab/logs/watchdog.log 2>/dev/null || echo '(no log yet)'"
}

$phones = @()
if ($Target -eq "both") {
    $phones = @("phone-b", "phone-a")
} else {
    $phones = @($Target)
}

foreach ($phone in $phones) {
    Write-Host ""
    Write-Host "--- $phone ---" -ForegroundColor Yellow
    Upload-WatchdogFiles $phone
    Upload-MeshEnvFiles $phone
    Install-Watchdog $phone
}

Write-Host ""
Write-Host "Watchdog deploy complete." -ForegroundColor Green
Write-Host "Verify: npm run smoke:watchdog"
