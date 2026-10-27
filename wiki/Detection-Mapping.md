# Detection Mapping: Request → Rule → Action

> Issue #9: *Monitoring & logging + verification*. Captured live on 2026-10-27 from the WAF (`swagpc-waf`) during `scripts/testing/verify-waf.sh`.

## What is logged, and where

| Source | Location | Contents | Persisted |
|---|---|---|---|
| ModSecurity audit log (JSON) | `/var/log/modsecurity/audit/audit.log` in `swagpc-waf` (volume `waf_audit`) | Timestamp, client IP, request line and headers, matched rule IDs and messages, interrupted flag, response status | Yes, named volume |
| Packet capture | `/tmp/attack.pcap` in `swagpc-firewall` (copied out) | Every TCP packet on ports 80 and 8080 that the firewall forwards | Saved as evidence |
| nginx access log | `/var/log/nginx/access.log` | Not written: the image sets `access_log off` in its location blocks | No (see Limitations) |

Evidence files for this run:
- [`evidence/verification/waf-audit-20261027T142318Z.log`](../evidence/verification/waf-audit-20261027T142318Z.log): the audit log
- [`evidence/verification/waf-attack-20261027T142318Z.pcap`](../evidence/verification/waf-attack-20261027T142318Z.pcap): the packet capture (124 packets)
- [`evidence/defense/waf-monitoring-verify-20261027T142318Z.txt`](../evidence/defense/waf-monitoring-verify-20261027T142318Z.txt): the check output (8 passed, 0 failed, 1 known gap)

## Detection mapping

Each row is one blocked request from the audit log. The action is the same for all rows: **HTTP 403, request denied before it reaches DVWA**.

| Time (UTC-equivalent, from the audit log) | Source | Request | Rule ID | Rule message | Action |
|---|---|---|---|---|---|
| 14:23:23 | 192.168.10.50 (Kali, Guest) | `GET /vulnerabilities/sqli/?id=1' UNION SELECT user,password FROM users#` | 942100 | SQL Injection Attack Detected via libinjection | 403 deny |
| 14:23:23 | 192.168.10.50 | (same request) | 942190 | Detects SQL code execution and information gathering attempts | 403 deny |
| 14:23:23 | 192.168.10.50 | (same request) | 942270 | Basic SQL injection patterns (MySQL, Oracle and others) | 403 deny |
| 14:23:23 | 192.168.10.50 | (same request) | 942360 | Concatenated basic SQL injection and SQLLFI | 403 deny |
| 14:23:23 | 192.168.10.50 | (same request) | 949110 | Inbound anomaly score exceeded (total 23). This is the blocking decision | 403 deny |
| 14:23:23 | 192.168.10.50 | `POST /vulnerabilities/exec/` with `ip=127.0.0.1;cat /etc/passwd` | 930120 | OS file access attempt | 403 deny |
| 14:23:23 | 192.168.10.50 | (same request) | 932160 | Remote command execution: Unix shell code | 403 deny |
| 14:23:23 | 192.168.10.50 | (same request) | 949110 | Inbound anomaly score exceeded (total 13). This is the blocking decision | 403 deny |

Rule 920350 (Host header is a numeric IP address) also fires on every request, including normal ones. It is informational and does not block.

**Mapping in one line:** a SQL injection request matches four SQLi rules, the anomaly score reaches the threshold of 5, and the WAF returns 403. A command injection matches two rules, and the same threshold applies.

## Verification against the acceptance criteria (#9)

- **WAF logs record the attempt (timestamp, request, rule, action):** met. Each blocked request has all four fields in the audit log.
- **A packet capture of the attack traffic is saved:** met. `waf-attack-*.pcap` holds 124 packets.

## Limitations

1. **nginx access log is empty.** The image's location config sets `access_log off`, so no per-request access line is written. The audit log covers the same ground for blocked requests. Allowed requests are not logged anywhere but the audit log's `RelevantOnly` mode, which records only blocked ones.
2. **Packet capture is not decrypted.** The lab uses plain HTTP, so the pcap shows the request text directly.
3. **Suricata and Wazuh are not in this mapping.** They are covered by #77 (custom rules) and #78 (agents), and by #62 (Suricata startup).
4. **Firewall log.** The network firewall's LOG rule (#76) writes to the kernel log, which the container cannot read, so it is not part of this capture.

## Reproduce

```bash
docker compose -f docker/docker-compose.yml up -d firewall dvwa kali waf
docker exec -d swagpc-firewall tcpdump -i any -U -s 0 -w /tmp/attack.pcap 'tcp port 8080 or tcp port 80'
bash scripts/testing/verify-waf.sh
docker exec swagpc-firewall pkill tcpdump
docker exec swagpc-waf cat /var/log/modsecurity/audit/audit.log
