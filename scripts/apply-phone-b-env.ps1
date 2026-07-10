# Apply agents-prod env profile on phone-b via SSH.
# Usage: .\scripts\apply-phone-b-env.ps1 -Profile live
#        .\scripts\apply-phone-b-env.ps1 -Profile stub

param(
    [Parameter(Mandatory)]
    [ValidateSet("stub", "live")]
    [string]$Profile,

    [ValidateSet("phone-a", "phone-b")]
    [string]$Phone = "phone-b"
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$ConfigDir = Join-Path $Root "config"
$Template = Join-Path $ConfigDir "agents-prod.phone-b.env.$Profile.example"
$SecretsFile = Join-Path $Root "mesh.secrets.env"

if (-not (Test-Path $Template)) {
    Write-Error "Template not found: $Template"
}

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

$secrets = Read-EnvFile $SecretsFile
$token = $secrets["INTERNAL_SERVICE_TOKEN"]
if (-not $token) { $token = "phone-lab-internal-token" }

$geminiKey = $secrets["GEMINI_API_KEY"]
if ($Profile -eq "live" -and -not $geminiKey) {
    Write-Error "GEMINI_API_KEY required in mesh.secrets.env for live profile"
}

$lines = Get-Content $Template
$out = New-Object System.Collections.Generic.List[string]
foreach ($line in $lines) {
    if ($line -match "^GEMINI_API_KEY=") {
        if ($Profile -eq "live" -and $geminiKey) {
            $out.Add("GEMINI_API_KEY=$geminiKey")
        } else {
            $out.Add("GEMINI_API_KEY=")
        }
        continue
    }
    if ($line -match "^INTERNAL_SERVICE_TOKEN=") {
        $out.Add("INTERNAL_SERVICE_TOKEN=$token")
        continue
    }
    $out.Add($line)
}

$tempAgents = Join-Path $env:TEMP "phone-lab-agents-prod.env"
[System.IO.File]::WriteAllLines($tempAgents, $out.ToArray(), (New-Object System.Text.UTF8Encoding $false))

Write-Host "=== Apply phone-b agents env: profile=$Profile ===" -ForegroundColor Cyan

Push-Location $Root
try {
    $remoteAgents = "~/phone-lab-agents-prod.env"
    python (Join-Path $PSScriptRoot "remote\ssh_upload.py") $Phone $tempAgents $remoteAgents
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    & (Join-Path $PSScriptRoot "remote-exec.ps1") $Phone "mkdir -p ~/phone-lab/packages/api-agents-prod && cp -f ~/phone-lab-agents-prod.env ~/phone-lab/packages/api-agents-prod/.env && sed -i 's/\r$//' ~/phone-lab/packages/api-agents-prod/.env"
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    $tokenPatch = "if [ -f ~/phone-lab/packages/api-content-prod/.env ]; then if grep -q '^INTERNAL_SERVICE_TOKEN=' ~/phone-lab/packages/api-content-prod/.env; then sed -i 's|^INTERNAL_SERVICE_TOKEN=.*|INTERNAL_SERVICE_TOKEN=$token|' ~/phone-lab/packages/api-content-prod/.env; else echo 'INTERNAL_SERVICE_TOKEN=$token' >> ~/phone-lab/packages/api-content-prod/.env; fi; fi"
    & (Join-Path $PSScriptRoot "remote-exec.ps1") $Phone $tokenPatch

    Write-Host "Applied $Profile profile to phone-b (agents + content-prod token sync)" -ForegroundColor Green
} finally {
    Pop-Location
    Remove-Item $tempAgents -ErrorAction SilentlyContinue
}
