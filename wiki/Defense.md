# Defense implementation

| Control | Implementation and evidence |
|---|---|
| Guest isolation | The [router policy](../defense/firewall/enable-segmentation.sh) logs and drops Guest-to-Business forwarding. The October 27 run recorded loss of ICMP reachability and an HTTP timeout. Matching router log evidence remains outstanding under #104. [segmentation comparison](../evidence/verification/segmentation-before-after.md) |
| Endpoint hardening | The [workstation controls](../defense/endpoint-hardening/README.md) apply to Alpine. The October 27 comparison records host firewall counters and local account settings. Windows Defender and SMB outcomes remain unverified. [workstation comparison](../evidence/verification/us9-endpoint-hardening.md) |
| Application controls | ModSecurity blocked the tested requests and allowed a benign lookup in the routed configuration. Direct-origin reachability varied by topology. The [DVWA security-level control](../defense/application-security/harden-dvwa-security-level.sh) is a separate layer whose before/after result remains unverified. [routed run](../evidence/defense/waf-routed-verify-20261027T135519Z.txt) |
| Monitoring | The [Compose configuration](../docker/docker-compose.yml) mounts the Suricata rule file. The [detection mapping](Detection-Mapping.md) records WAF rule matches. A current Suricata signature linked to a Wazuh event and measured latency remains outstanding under #107. |

The [defense matrix](Defense-Test-Matrix.md) lists the observed configurations and the evidence still needed for each control.
