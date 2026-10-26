# Build the dashboard on your own computer (Windows).
#   powershell -ExecutionPolicy Bypass -File refresh.ps1         read your GitHub repository
#   powershell -ExecutionPolicy Bypass -File refresh.ps1 -Demo   use made-up sample data
# Then open _site\index.html in your browser.
param([switch]$Demo)
$ErrorActionPreference = "Stop"
Set-Location -Path $PSScriptRoot

# "python3.exe" can be the Microsoft Store alias, which opens the Store instead of running Python,
# so only accept a command that answers --version with a real Python 3.
$py = $null
foreach ($c in @("py", "python", "python3")) {
    try {
        $v = & $c --version 2>&1 | Out-String
        if ($LASTEXITCODE -eq 0 -and $v -match "Python 3\.(\d+)" -and [int]$Matches[1] -ge 9) { $py = $c; break }
    } catch { }
}
if (-not $py) {
    Write-Output "Python 3.9 or later is required. Install it from https://www.python.org/downloads/ and tick 'Add python.exe to PATH'."
    exit 1
}

if (-not $Demo -and -not $env:GH_TOKEN -and -not $env:GITHUB_TOKEN) {
    $gh = Get-Command gh -ErrorAction SilentlyContinue
    if (-not $gh) {
        Write-Output "Sign in to GitHub first: install the GitHub CLI (https://cli.github.com) and run: gh auth login"
        exit 1
    }
    & gh auth status *> $null
    if ($LASTEXITCODE -ne 0) {
        Write-Output "Sign in to GitHub first: gh auth login"
        exit 1
    }
}

$scriptArgs = @("scripts/generate_dashboard.py")
if ($Demo) { $scriptArgs += "--demo" }
& $py @scriptArgs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Write-Output ("Open this file in your browser: " + (Join-Path (Get-Location) "_site\index.html"))
