# sync-rules.ps1
# Ensures GEMINI.md, CLAUDE.md, and AGENTS.md remain 100% identical.
param(
    [string]$Source = "GEMINI.md"
)

if (-not (Test-Path $Source)) {
    Write-Host "Source file $Source does not exist!" -ForegroundColor Red
    exit 1
}

$targets = @("GEMINI.md", "CLAUDE.md", "AGENTS.md") | Where-Object { $_ -ne $Source }

foreach ($t in $targets) {
    Copy-Item $Source $t -Force
    Write-Host "Synchronized $t from $Source" -ForegroundColor Green
}
Write-Host "All agent rule files are in sync!" -ForegroundColor Cyan
