# Café security tool for Windows

Use Windows with Docker Desktop's Linux engine and the base café Compose project. Build and run from the `security-tool` directory. The existing repository-root entry point also works.

| Tool file | Purpose |
|---|---|
| [CafeSecurity.cs](CafeSecurity.cs) | Windows command-line application |
| [waf-policy.sh](waf-policy.sh) | Router policy embedded in the executable at build time |
| [build.ps1](build.ps1) | Builds `CafeSecurity.exe` in this directory |
| [TargetChecks.cs](TargetChecks.cs) and [test-waf-policy.sh](test-waf-policy.sh) | Offline Windows and routing regression checks |

The parent repository owns the Docker Compose lab definition. The tool uses it to identify the supported café stack.

```powershell
# From the capstone repository
cd security-tool
& "$env:WINDIR\Microsoft.NET\Framework64\v4.0.30319\csc.exe" /nologo /target:exe /out:CafeSecurity.exe /resource:waf-policy.sh,waf-policy.sh CafeSecurity.cs
if ($LASTEXITCODE) { throw 'Build failed' }
.\CafeSecurity.exe preflight
.\CafeSecurity.exe status
.\CafeSecurity.exe check-target
```

| Command | Behavior |
|---|---|
| `preflight` | Reads the base Compose configuration and checks for the four required services. |
| `status` | Additionally checks whether Docker lists those services as running. |
| `check-target` | Inspects the running containers on the local Docker Desktop Linux pipe. Requires the base checkout and Compose labels, expected bridge attachments and addresses, IPv4 forwarding, Guest routes through the router, and DVWA's configured Low default. |
| `verify-waf` | Verifies the DVWA Low default and topology, checks the origin login page locally and the WAF login page from Guest, then checks a fresh Guest connection to the direct origin. A timeout with an increased router deny counter is required. |
| `apply-waf` | Runs the target checks and installs the café Guest-to-Business WAF policy on the identified router. The transaction admits the base WAF port and established flows and drops other new Guest-to-Business traffic. Existing sessions may continue. After installation the executable runs the same benign checks as `verify-waf`. Other traffic continues through the original policy. |
| `rollback-waf` | Checks the same router's identity and removes the tool-owned rules. Recovery can run while the other three services are down. |

The compiler command above and the optional `build.ps1` helper both embed the firewall policy in the executable. Exit 0 means the requested operation succeeded, 1 means it failed or was blocked, and 2 indicates invalid usage. If the traffic checks fail immediately after a fresh installation, the tool attempts to restore the prior rules. Failure on an already-managed configuration leaves it available for inspection. The deny counter covers the Guest subnet; perform the live acceptance run (#146) in a quiet, isolated lab. DVWA's configured default and a browser session's selected level are separate.

**Recovery scope.** The router needs `iptables`, `iptables-restore` and `flock`. Before changing FORWARD the tool records the previous policy listing inside the router under `/run/swagpc-cafe-waf`. Repeated operations recognize the managed rules. If another administrator changes FORWARD, inspect the router and journal before retrying. Keep the same router container for recovery; recreating it can discard its rules and journal. The isolated Windows replay exercised apply, repeat, explicit rollback and automatic recovery after a failed verification. [Historical WAF evidence](../wiki/WAF-Verification.md).

## Eligibility for the executable

Ant Huynh (@UiwAntHuynhCIS) owns the integration decisions and follow-ups below.

| Capability and intended target | Project evidence or prerequisite | Decision |
|---|---|---|
| WAF-only routing on the base café stack | [Routed WAF run](../evidence/defense/waf-routed-verify-20261027T135519Z.txt); restore the actual previous policy (#145) and demonstrate it through the tool (#146). | Live enforcement and recovery demonstrated in the isolated fixture. Verification against #127's supported startup modes is pending. |
| Guest isolation on the Alpine router | [Baseline and defended comparison](../evidence/verification/segmentation-before-after.md); finish allowed-flow and denial evidence (#104, #105). | Recovery demonstrated in the validation fixture. |
| Alpine employee workstation | [Endpoint comparison](../evidence/verification/us9-endpoint-hardening.md); demonstrate identity checks, permitted business traffic and recovery. | Firewall recovery demonstrated in the validation fixture. |
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

## Isolated live verification

The fixture uses separately named bridges and containers, with no published ports. Start only the four listed services. The replay removes the fixture's default routes and adds return routes through the café router. Run the replay against a fresh validation router. It temporarily changes that router's FORWARD policy and restores it.

```powershell
docker compose -p cafe-waf-validation -f docker/docker-compose.yml -f docker/docker-compose.waf-validation.yml build firewall
docker compose -p cafe-waf-validation -f docker/docker-compose.yml -f docker/docker-compose.waf-validation.yml up -d --no-build firewall kali dvwa waf
```

From the repository root with the Windows tool built and the WAF service healthy, run `sh security-tool/verify-waf-live.sh` with a shell that can invoke Docker Desktop. Stop the fixture afterward with the same Compose project and files and the `stop` command.

The November 22 run used Docker Engine 29.8.2 and implementation commit `e8bcb39`. Before apply and after rollback, the Guest reached the direct login page with HTTP 200. During enforcement the healthy WAF returned 200, a new direct connection timed out, and the deny counter increased. Repeated apply left the rules identical. The run also proved automatic restoration after a deliberately interrupted WAF return path. DVWA's configured default was Low before and after. The fixture is separate from the persistent startup modes tracked by #127, which still gate final acceptance of #146. [Live evidence](../evidence/verification/us25-waf-live-20261122T160650Z.txt).

## Router and workstation firewall recovery (#150)

This recovery procedure is a capstone lab feature. The Windows executable's WAF commands are separate. The wrapper checks the running Docker Compose project, container name and ID, unpublished ports, bridge ownership, addresses and subnets before dispatching to the identified container.

Start the four services described in the [permitted traffic replay](../wiki/Firewall-Rules.md#permitted-traffic-replay-105), with fresh router and workstation containers. From the repository root, run `sh scripts/testing/verify-firewall-recovery.sh`. The replay uses the isolated workstation and business portal. For a manual recovery operation within that fixture, run `sh defense/firewall/recovery-firewall.sh router rollback` or `sh defense/firewall/recovery-firewall.sh workstation rollback`.

Each control adds an owned chain ahead of the prior rules in one kernel transaction. Allowed traffic returns to the prior policy for a decision. The operations journal the starting chain and refuse observed rule drift. Run in a quiet fixture and retain the same container for recovery. The journal does not survive recreation. Keep other firewall rule writers idle during the operation.

The live replay verified repeated apply, explicit rollback, and rollback after termination immediately following the kernel commit. Both custom starting policies used default DROP and were restored exactly. The employee portal remained reachable, Guest requests were blocked and attributed to the managed chains, and a pre-existing Business ICMP restriction still worked. Account hardening is outside this firewall procedure. [Live evidence](../evidence/verification/us25-firewall-recovery-20261123T020942Z.txt) · [Tested implementation 72ba1fc](https://github.com/bash-y/CIS_CapstoneProj_Swag01erload/commit/72ba1fc88f7b0f1bf8bc5f2b44e4732fb874e138) · [Permitted traffic evidence](../evidence/verification/us8-permitted-traffic-20261123T010217Z.txt) · [Router denial evidence](../evidence/verification/us8-router-nflog-20261123T014940Z.txt)
