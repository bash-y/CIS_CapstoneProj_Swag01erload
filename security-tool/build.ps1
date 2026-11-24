$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot
try {
    $compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
    & $compiler /nologo /target:exe /out:CafeSecurity.exe /resource:waf-policy.sh,waf-policy.sh CafeSecurity.cs
    if ($LASTEXITCODE -ne 0) { throw "C# build failed ($LASTEXITCODE)." }
} finally {
    Pop-Location
}
