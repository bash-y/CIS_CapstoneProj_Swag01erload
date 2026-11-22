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

## Eligibility for the executable

Ant Huynh (@UiwAntHuynhCIS) owns the integration decisions and follow-ups below.

| Capability and intended target | Project evidence or prerequisite | Decision |
|---|---|---|
| WAF-only routing on the base café stack | [Routed WAF run](../evidence/defense/waf-routed-verify-20261027T135519Z.txt); restore the actual previous policy (#145) and demonstrate it through the tool (#146). | Service inventory available. Enforcement pending. |
| Guest isolation on the Alpine router | [Baseline and defended comparison](../evidence/verification/segmentation-before-after.md); finish allowed-flow and denial evidence (#104, #105). | Pending #147. |
| Alpine employee workstation | [Endpoint comparison](../evidence/verification/us9-endpoint-hardening.md); demonstrate identity checks, permitted business traffic and recovery. | Pending #147. |
| Login throttling | Existing project issue #109 requires paired results for legitimate login, throttling and recovery. | Project prerequisite open. |
| Stored XSS defense on DVWA Low | Implement team-authored output encoding and demonstrate that stored text displays safely in a separate session. | Candidate for project work. |
| MFA | Select a supported identity system and demonstrate enrollment, authentication and recovery in the project. | Candidate for project work. |
| Installer or second environment | Implement and test installation, removal and recovery on each proposed platform. | Future packaging work. |
