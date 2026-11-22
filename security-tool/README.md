# Café security tool for Windows

Run from the café repository root on Windows with Docker Desktop and its Linux engine. The first release inventories the four services needed for the team's existing base WAF configuration. It checks the local Docker Desktop named pipe.

Build in PowerShell using the .NET Framework compiler:

```powershell
Push-Location security-tool
try {
    & "$env:WINDIR\Microsoft.NET\Framework64\v4.0.30319\csc.exe" /nologo /target:exe /out:CafeSecurity.exe CafeSecurity.cs
    if ($LASTEXITCODE -ne 0) { throw 'Build failed' }
} finally { Pop-Location }

.\security-tool\CafeSecurity.exe preflight
.\security-tool\CafeSecurity.exe status
```

`preflight` lists the required services declared in the base Compose file. `status` additionally checks which services Docker reports as running. Exit 0 means the requested inventory passed, 1 means the check failed or was blocked, and 2 indicates invalid usage. Service inventory provides no measurement of routing, origin isolation, application readiness or the DVWA level.

US-25 tracks enforcement and recovery in #145, live verification in #146, and qualification of other existing project defenses in #147. Keep DVWA on Low during the demonstration. [Existing WAF evidence](../wiki/WAF-Verification.md).
