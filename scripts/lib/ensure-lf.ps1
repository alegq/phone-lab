# Normalize shell scripts to LF line endings for Termux/bash.
function Convert-ShFilesToLf {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Directory
    )

    if (-not (Test-Path $Directory)) {
        Write-Error "Directory not found: $Directory"
    }

    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    Get-ChildItem -Path $Directory -Filter '*.sh' -Recurse -File | ForEach-Object {
        $text = [System.IO.File]::ReadAllText($_.FullName)
        $normalized = $text -replace "`r`n", "`n" -replace "`r", "`n"
        if ($normalized -ne $text) {
            [System.IO.File]::WriteAllText($_.FullName, $normalized, $utf8NoBom)
            Write-Host "  LF: $($_.Name)" -ForegroundColor DarkGray
        }
    }
}
