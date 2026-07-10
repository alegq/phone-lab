# Migrate content PostgreSQL from k3s-dev to phone-b.
# Run from phone-lab repo root.
# Requires: WSL kubectl (k3s-dev), mesh.env, SSH to phone-b.

param(
    [ValidateSet("phone-b", "phone-a")]
    [string]$Phone = "phone-b",
    [string]$K8sContext = "k3s-dev",
    [string]$Namespace = "ezrababait",
    [string]$Pod = "content-postgres-sts-0"
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$SshExec = Join-Path $PSScriptRoot "remote\ssh_exec.py"
$SshUpload = Join-Path $PSScriptRoot "remote\ssh_upload.py"
$DumpLocal = Join-Path $Root "tmp-content-dump.sql"

function Invoke-Ssh([string]$Target, [string]$Command) {
    python $SshExec $Target $Command
    return $LASTEXITCODE
}

Write-Host "=== Phone Lab: migrate content DB (k3s-dev -> $Phone) ===" -ForegroundColor Cyan

Write-Host "Dumping from k3s-dev ($Pod)..."
$wslCmd = 'set -euo pipefail; kubectl config use-context ' + $K8sContext + ' >/dev/null; kubectl exec -n ' + $Namespace + ' ' + $Pod + ' -- pg_dump -U admin -d content --clean --if-exists --no-owner --no-acl -f /tmp/content-dump.sql; kubectl cp ' + $Namespace + '/' + $Pod + ':/tmp/content-dump.sql /mnt/c/workspace/Ezrababait-2023/phone-lab/tmp-content-dump.sql'
wsl -e bash -lc $wslCmd
if ($LASTEXITCODE -ne 0) { throw "pg_dump from k3s-dev failed" }

if (-not (Test-Path $DumpLocal)) {
    throw "Dump file not found: $DumpLocal"
}

$size = (Get-Item $DumpLocal).Length
Write-Host "Dump size: $size bytes"
if ($size -lt 100) {
    throw "Dump file too small - likely failed"
}

Write-Host "Ensuring content DB on $Phone..."
if ($Phone -eq "phone-a") {
    Invoke-Ssh $Phone 'bash ~/phone-lab/packages/api-content-prod/scripts/termux/phone-a/setup-content-data-plane.sh' | Out-Null
} else {
    Invoke-Ssh $Phone 'bash ~/phone-lab/packages/api-content-prod/scripts/termux/phone-b/setup-content-db.sh' | Out-Null
}
if ($LASTEXITCODE -ne 0) { throw "setup-content-db failed" }

Write-Host "Uploading dump to $Phone..."
python $SshUpload $Phone $DumpLocal "~/content-dump.sql"
if ($LASTEXITCODE -ne 0) { throw "upload failed" }

Write-Host "Restoring dump on $Phone..."
Invoke-Ssh $Phone 'psql -U admin -d content -f ~/content-dump.sql 2>&1' | Out-Host
if ($LASTEXITCODE -ne 0) { throw "psql restore failed" }

Write-Host "Verifying row counts..."
Invoke-Ssh $Phone @"
psql -U admin -d content -tAc 'SELECT COUNT(*) FROM blog_posts' 2>/dev/null || echo 0
psql -U admin -d content -tAc 'SELECT COUNT(*) FROM blog_template_drafts' 2>/dev/null || echo 0
"@ | Out-Host

Invoke-Ssh $Phone 'rm -f ~/content-dump.sql' | Out-Null
Remove-Item $DumpLocal -ErrorAction SilentlyContinue

Write-Host "Content DB migration complete." -ForegroundColor Green
