# Deploy Phone Lab pull-deploy scripts to phone-b + install cron.
# Run from phone-lab repo root.
# Prerequisites: mesh.env, SSH keys (npm run remote:setup).

param(
    [ValidateSet("phone-b")]
    [string]$Target = "phone-b",
    [switch]$SkipInstall
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "lib\ensure-lf.ps1")

$Root = Split-Path -Parent $PSScriptRoot
$SshExec = Join-Path $PSScriptRoot "remote\ssh_exec.py"
$SshUpload = Join-Path $PSScriptRoot "remote\ssh_upload.py"
$TermuxRoot = Join-Path $Root "scripts\termux"

Write-Host "=== Phone Lab: deploy pull-deploy (GitHub Release -> phone-b) ===" -ForegroundColor Cyan

$PullDeployFiles = @(
    @{ Local = "lib\pull-deploy-lib.sh"; RemoteDir = "lib" },
    @{ Local = "phone-b\pull-deploy-agents.sh"; RemoteDir = "phone-b" },
    @{ Local = "phone-b\install-pull-deploy-cron.sh"; RemoteDir = "phone-b" }
)

Write-Host "Normalizing .sh line endings (LF)..."
Convert-ShFilesToLf -Directory (Join-Path $TermuxRoot "lib")
Convert-ShFilesToLf -Directory (Join-Path $TermuxRoot "phone-b")

function Invoke-Ssh([string]$Phone, [string]$Command) {
    python $SshExec $Phone $Command
    return $LASTEXITCODE
}

function Upload-PullDeployFiles([string]$Phone) {
    Write-Host "Uploading pull-deploy scripts to $Phone..." -ForegroundColor Cyan
    Invoke-Ssh $Phone "mkdir -p ~/phone-lab/scripts/termux/lib ~/phone-lab/scripts/termux/phone-b ~/phone-lab/config ~/phone-lab/data ~/phone-lab/logs" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "mkdir failed on $Phone" }

    foreach ($item in $PullDeployFiles) {
        $localPath = Join-Path $TermuxRoot $item.Local
        if (-not (Test-Path $localPath)) {
            throw "Missing $localPath"
        }
        $remotePath = "~/phone-lab/scripts/termux/$($item.RemoteDir)/$(Split-Path -Leaf $localPath)"
        python $SshUpload $Phone $localPath $remotePath
        if ($LASTEXITCODE -ne 0) { throw "upload failed: $($item.Local) -> $Phone" }
    }

    $configExample = Join-Path $Root "config\pull-deploy.env.example"
    if (Test-Path $configExample) {
        python $SshUpload $Phone $configExample "~/phone-lab/config/pull-deploy.env.example"
        if ($LASTEXITCODE -ne 0) { Write-Host "WARN: config example upload failed" -ForegroundColor Yellow }
        Invoke-Ssh $Phone "test -f ~/phone-lab/pull-deploy.env || cp ~/phone-lab/config/pull-deploy.env.example ~/phone-lab/pull-deploy.env" | Out-Null
    }

    Invoke-Ssh $Phone "find ~/phone-lab/scripts/termux -name '*.sh' -exec chmod +x {} + ; find ~/phone-lab/scripts/termux -name '*.sh' -exec sed -i 's/\r$//' {} +" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "chmod/sed failed on $Phone" }
}

function Install-PullDeploy([string]$Phone) {
    $installScript = "~/phone-lab/scripts/termux/phone-b/install-pull-deploy-cron.sh"
    $pullScript = "~/phone-lab/scripts/termux/phone-b/pull-deploy-agents.sh"

    if (-not $SkipInstall) {
        Write-Host "Installing pull-deploy cron on $Phone..."
        Invoke-Ssh $Phone "bash $installScript"
        if ($LASTEXITCODE -ne 0) { throw "install-pull-deploy-cron failed on $Phone" }
    }

    Write-Host "Dry-run on $Phone..."
    Invoke-Ssh $Phone "bash $pullScript --dry-run"
    $dryCode = $LASTEXITCODE
    if ($dryCode -ne 0) {
        Write-Host "WARN: dry-run returned $dryCode (token or release may be missing)" -ForegroundColor Yellow
    }

    Write-Host "Recent pull-deploy log on ${Phone}:"
    Invoke-Ssh $Phone "tail -10 ~/phone-lab/logs/pull-deploy.log 2>/dev/null || echo '(no log yet)'"
}

Write-Host ""
Write-Host "--- $Target ---" -ForegroundColor Yellow
Upload-PullDeployFiles $Target
Install-PullDeploy $Target

Write-Host ""
Write-Host "Pull-deploy scripts deployed." -ForegroundColor Green
Write-Host "On phone-b: set GITHUB_TOKEN in ~/phone-lab/mesh.secrets.env"
Write-Host "On phone-b: set PULL_DEPLOY_AGENTS_ENABLED=1 in ~/phone-lab/pull-deploy.env"
Write-Host "Guide: docs/PULL-DEPLOY.md"
