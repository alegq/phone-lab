# Run a command on phone-a or phone-b via Termux SSH.
# Usage: .\scripts\remote-exec.ps1 phone-b "whoami"
#        .\scripts\remote-exec.ps1 phone-a "tail -20 ~/phone-lab/logs/gateway-prod.log"

param(
    [Parameter(Mandatory)][ValidateSet("phone-a", "phone-b")][string]$Phone,
    [Parameter(Mandatory)][string]$Command
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
Push-Location $Root
try {
    python (Join-Path $PSScriptRoot "remote\ssh_exec.py") $Phone $Command
    exit $LASTEXITCODE
} finally {
    Pop-Location
}
