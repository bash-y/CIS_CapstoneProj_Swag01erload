# Web application firewall

The café lab uses an nginx reverse proxy with ModSecurity and the OWASP Core Rule Set in front of DVWA. The base Compose configuration publishes the proxy on the host at `127.0.0.1:8081`. Inside the base lab the proxy listens at `192.168.20.15:8080`. Requests that reach DVWA directly skip inspection. [Compose configuration](../docker/docker-compose.yml)

## What the lab demonstrated

On October 27, 2026, a benign lookup through the proxy returned HTTP 200 and one row. The tested SQL injection and command injection requests each returned HTTP 403 with no requested data. The audit log recorded rule IDs 942100 and 932160, respectively. These observations cover the requests in that run. They establish WAF behavior at the proxy. End-to-end Suricata and Wazuh delivery requires separate evidence. [Verification record](WAF-Verification.md) · [Audit event mapping](Detection-Mapping.md)

## When the proxy enforced the policy

| Recorded configuration | Direct Guest access to DVWA | Evidence |
|---|---|---|
| Initial proxy check | The origin remained reachable. The proxy blocked the tested requests sent through it. | [7 passes, 1 known gap](../evidence/defense/waf-verify-20261027T133314Z.txt) |
| Routed configuration | The direct origin check was blocked. | [8 passes, 0 known gaps](../evidence/defense/waf-routed-verify-20261027T135519Z.txt) |
| Monitoring capture | The direct path was reachable during this capture. Its audit events describe traffic sent through the WAF. | [8 passes, 1 known gap](../evidence/defense/waf-monitoring-verify-20261027T142318Z.txt) |
| Three-segment configuration | Guest could reach the proxy at `192.168.10.15`. Direct access to the origin at `192.168.30.10` was blocked, and the proxy refused the Guest setup-page request. | [9 passes, 0 known gaps](../evidence/defense/segmented-verify-20261027T143306Z.txt) · [Network layout](Network-Segmentation.md) |

The [defense matrix](Defense-Test-Matrix.md) tracks application hardening separately. A 403 from ModSecurity measures proxy enforcement. Verifying DVWA's own input handling requires a direct application comparison.
