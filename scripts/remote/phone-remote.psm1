# Remote Termux access from dev PC (SSH over Tailscale).
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$RemoteDir = Join-Path $PSScriptRoot "remote"

function Invoke-PhoneRemote {
    param(
        [Parameter(Mandatory)][string]$Phone,
        [Parameter(Mandatory)][string]$Command
    )
    Push-Location $Root
    try {
        python (Join-Path $RemoteDir "ssh_exec.py") $Phone $Command
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    } finally {
        Pop-Location
    }
}

function Send-PhoneFile {
    param(
        [Parameter(Mandatory)][string]$Phone,
        [Parameter(Mandatory)][string]$LocalPath,
        [Parameter(Mandatory)][string]$RemotePath
    )
    Push-Location $Root
    try {
        python (Join-Path $RemoteDir "ssh_upload.py") $Phone $LocalPath $RemotePath
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    } finally {
        Pop-Location
    }
}

function Install-PhoneSshKeys {
    param([string[]]$Phones = @("phone-a", "phone-b"))
    Push-Location $Root
    try {
        $key = Join-Path $env:USERPROFILE ".ssh\phone-lab"
        if (-not (Test-Path $key)) {
            Write-Host "Generating SSH key $key ..."
            ssh-keygen -t ed25519 -f $key -N '""' -q
        }
        python (Join-Path $RemoteDir "setup_ssh_keys.py") @Phones
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        Write-Host ""
        Write-Host "SSH config snippet (~/.ssh/config):" -ForegroundColor Cyan
        Get-Content (Join-Path $RemoteDir "ssh-config.snippet")
    } finally {
        Pop-Location
    }
}

Export-ModuleMember -Function Invoke-PhoneRemote, Send-PhoneFile, Install-PhoneSshKeys
