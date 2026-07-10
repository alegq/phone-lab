# Deploy session-start scripts + Termux login hook (phone-a / phone-b).
# Run from phone-lab repo root after closing/reopening Termux should auto-start the stack.
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

Write-Host "=== Phone Lab: deploy session-start (Termux login hook) ===" -ForegroundColor Cyan

$SessionFiles = @(
    @{ Local = "lib\session-start-lib.sh"; RemoteDir = "lib" },
    @{ Local = "lib\watchdog-lib.sh"; RemoteDir = "lib" },
    @{ Local = "phone-a\session-start-phone-a.sh"; RemoteDir = "phone-a" },
    @{ Local = "phone-a\boot-gateway-phone-a.sh"; RemoteDir = "phone-a" },
    @{ Local = "phone-a\openclaw-env.sh"; RemoteDir = "phone-a" },
    @{ Local = "phone-a\restart-openclaw-phone-a.sh"; RemoteDir = "phone-a" },
    @{ Local = "phone-b\session-start-phone-b.sh"; RemoteDir = "phone-b" },
    @{ Local = "phone-b\boot-stack-phone-b.sh"; RemoteDir = "phone-b" },
    @{ Local = "install-termux-login-hook.sh"; RemoteDir = "." }
)

Write-Host "Normalizing .sh line endings (LF)..."
Convert-ShFilesToLf -Directory $TermuxRoot

function Invoke-Ssh([string]$Phone, [string]$Command) {
    python $SshExec $Phone $Command
    return $LASTEXITCODE
}

function Upload-SessionFiles([string]$Phone) {
    Write-Host "Uploading session-start scripts to $Phone..." -ForegroundColor Cyan
    Invoke-Ssh $Phone "mkdir -p ~/phone-lab/scripts/termux/lib ~/phone-lab/scripts/termux/phone-a ~/phone-lab/scripts/termux/phone-b" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "mkdir failed on $Phone" }

    foreach ($item in $SessionFiles) {
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

function Install-SessionHook([string]$Phone) {
    if (-not $SkipInstall) {
        Write-Host "Installing login hook on $Phone..."
        Invoke-Ssh $Phone "bash ~/phone-lab/scripts/termux/install-termux-login-hook.sh $Phone"
        if ($LASTEXITCODE -ne 0) { throw "install-termux-login-hook failed on $Phone" }
    }

    Write-Host "Testing session-start once on $Phone (dry run)..."
    Invoke-Ssh $Phone "timeout 300 bash ~/phone-lab/scripts/termux/$Phone/session-start-$Phone.sh"
    $code = $LASTEXITCODE
    if ($code -ne 0) {
        Write-Host "WARN: session-start returned $code on $Phone" -ForegroundColor Yellow
    }

    Write-Host "Recent session-start log on ${Phone}:"
    Invoke-Ssh $Phone "tail -10 ~/phone-lab/logs/session-start.log 2>/dev/null || echo '(no log yet)'"
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
    Upload-SessionFiles $phone
    Install-SessionHook $phone
}

Write-Host ""
Write-Host "Session-start deploy complete." -ForegroundColor Green
Write-Host "Nightly: close Termux, next morning open Termux - stack auto-starts in background."
Write-Host "Log: ~/phone-lab/logs/session-start.log"
