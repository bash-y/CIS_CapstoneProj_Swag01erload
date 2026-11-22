# Defense test matrix

## Recorded results

These records cover October 27, 2026. The endpoints and enforcement layer matter when comparing results. The workstation firewall check used open routing. The WAF captures used several different layouts.

| Defense and acceptance measure | Check and observed result | Evidence |
|---|---|---|
| Router isolation (US-8). Guest loses ICMP access to both tested Business hosts. | From the lab Guest container, `ping -c 2 -W 2` to 192.168.20.10 and 192.168.20.25. Both answered before segmentation and showed 100% loss after. | [segmentation comparison](../evidence/verification/segmentation-before-after.md) |
| Router isolation (US-8). Guest loses HTTP access to DVWA. | Guest request to `http://192.168.20.10:80/` returned HTTP 302 before segmentation. The follow-up curl and TCP checks timed out. The original suite misclassified the timeout (#64). | [segmentation comparison](../evidence/verification/segmentation-before-after.md), [direct checks](../evidence/verification/segmentation-ground-truth.txt), [suite output](../evidence/verification/verify-defenses-after.txt) |
| WAF (US-10). Benign lookup succeeds and both tested injection requests receive 403. | [WAF verification script](../scripts/testing/verify-waf.sh). The routed run recorded 8 passes and denied direct origin access. The monitoring run recorded 8 passes and one direct-access gap. The three-segment run recorded 9 passes, including direct-origin denial, using WAF 192.168.10.15 and origin 192.168.30.10. | [routed run](../evidence/defense/waf-routed-verify-20261027T135519Z.txt), [monitoring run](../evidence/defense/waf-monitoring-verify-20261027T142318Z.txt), [three-segment run](../evidence/defense/segmented-verify-20261027T143306Z.txt) |
| Workstation host firewall (US-9). Guest loses access at the endpoint. | With router forwarding open, Guest ping to 192.168.20.25 changed from 3/3 replies to 100% loss. The endpoint LOG and DROP counters recorded six packets each. The account inspection recorded a nonprivileged employee and locked root account. [Controls and check procedure](../defense/endpoint-hardening/README.md). | [workstation comparison](../evidence/verification/us9-endpoint-hardening.md) |
| Employee-to-server reachability (US-4). ICMP, TCP 80 and the portal respond. | `sh scripts/testing/verify-workstation-to-server.sh` passed all three checks in the recorded build. A matched post-hardening run is pending. | [Build check](../evidence/build/us4-workstation-to-server.txt) |

## Outstanding acceptance evidence

| Control | Required observation |
|---|---|
| Router denial logging (#104) | Match a denied client probe to the router's `FW-DROP-GUEST` record by source, destination, protocol and time. The [router policy](../defense/firewall/enable-segmentation.sh) contains the rule. |
| Permitted traffic (#105) | Record the same authorized business-service probes before and after hardening with a blocked Guest control. The lab models no pfSense WAN. |
| DVWA hardening (#51) | Compare direct application behavior before and after applying the security-level control. The WAF result measures a separate layer. |
| Login throttling and authorization (#109, #110) | Verify the lockout threshold, legitimate recovery, authorized operations and denial of unauthorized requests against the deployed controls. Dated paired results are missing. |
| Suricata and Wazuh (#107) | Capture a fresh Suricata event with source and signature, its corresponding Wazuh event, and elapsed time against the 60-second target. The [Compose rule mount](../docker/docker-compose.yml) and WAF audit matches alone establish no delivery time. |
| Native platforms (#103) | Native pfSense, tagged VLANs and Windows controls require platform evidence or a recorded rubric decision. See [Architecture](Architecture.md). |
