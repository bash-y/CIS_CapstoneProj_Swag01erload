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
| Guest isolation on the Alpine router | [Baseline and defended comparison](../evidence/verification/segmentation-before-after.md); finish allowed-flow and denial evidence (#104, #105). | Hold integration pending #104, #105 and #150. |
| Alpine employee workstation | [Endpoint comparison](../evidence/verification/us9-endpoint-hardening.md); demonstrate identity checks, permitted business traffic and recovery. | Hold integration pending endpoint-specific evidence and #150. |
| Login throttling | Existing project issue #109 requires paired results for legitimate login, throttling and recovery. | Project prerequisite open. |
| Stored XSS defense on DVWA Low | Implement team-authored output encoding and demonstrate that stored text displays safely in a separate session. | Candidate for project work. |
| MFA | Select a supported identity system and demonstrate enrollment, authentication and recovery in the project. | Candidate for project work. |
| Installer or second environment | Implement and test installation, removal and recovery on each proposed platform. | Future packaging work. |

### Guest isolation qualification (#147)

**Decision: retain the router control as a lab procedure.** In the October 27 [comparison](../evidence/verification/segmentation-before-after.md), Guest lost ICMP access to DVWA and the employee workstation, and HTTP to DVWA timed out. The later [router script](../defense/firewall/enable-segmentation.sh) contains a log rule. The client timeouts alone cannot identify a matching router log entry (#104).

| Integration gate | Evidence required to release the control |
|---|---|
| Scope and policy | Identify the local café router, Guest and Business interfaces, and selected policy before applying it (#150). Full Guest isolation drops new Guest connections to the base layout's Business-side WAF. Its earlier ESTABLISHED,RELATED rule permits existing flows. WAF-only routing needs its own policy (#145). |
| Permitted traffic | The [workstation-to-server check](../evidence/build/us4-workstation-to-server.txt) passed during the build. Record paired allowed flows and a blocked Guest control with segmentation active (#105). The same-subnet workstation check alone cannot establish that a forwarded route works. |
| Recovery | The [baseline reset](../defense/firewall/disable-segmentation.sh) flushes FORWARD and selects ACCEPT. Preserve and restore an existing non-default policy, including unrelated rules, and exercise recovery after a partial apply (#150). |

### Alpine workstation qualification (#147)

**Decision: keep the host firewall and account policy out of the executable until each can be recovered independently.** With router forwarding open, Guest ping changed from three replies to 100% loss. The workstation INPUT counters recorded six packets each for LOG and DROP. The same dated record shows the employee group membership, password-aging settings and root lock state. [Endpoint evidence](../evidence/verification/us9-endpoint-hardening.md)

| Control | Qualification finding and release condition |
|---|---|
| Workstation firewall | The [apply script](../defense/endpoint-hardening/harden-workstation-firewall.sh) selects a fixed container name and replaces its INPUT rules. Its [baseline reset](../defense/endpoint-hardening/unharden-workstation-firewall.sh) opens inbound traffic. Identify the intended Alpine workstation and Business network first. Record a permitted Business-to-workstation check against a healthy lab service, a denied Guest check with open router forwarding, and restoration of the exact prior INPUT policy (#128, #150). |
| Local accounts | The [account script](../defense/endpoint-hardening/harden-workstation-accounts.sh) changes group membership, aging policy and account locks. The October record proves selected resulting settings. Capture which accounts will change and demonstrate restoration of the previous settings on disposable lab accounts before packaging this operation (#150). |
