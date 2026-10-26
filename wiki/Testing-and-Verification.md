# Testing & Verification

Every implemented defense is verified by re-running the exact same attack tools and payloads used in the undefended demonstration, proving that traffic is denied, restricted, or alerted.

---

## Defense Verification Matrix

| # | Defense Tested | Repeat Attack Command | Expected Result | Verified Result | Evidence Artifact |
|---|---|---|---|---|---|
| **1** | **pfSense Guest Isolation** | `nmap -sn 192.168.20.0/24` from Kali (`192.168.10.50`) | 100% packet loss / 0 hosts up in business network | Passed (Dropped) | `evidence/defense/pfsense-drop-log.png` |
| **2** | **pfSense Access Control** | `curl -I http://192.168.20.10:8080` from Kali | Connection timed out / packet dropped by firewall | Passed (Timeout) | `evidence/defense/firewall-block.png` |
| **3** | **Application Hardening** | `127.0.0.1; cat /etc/passwd` injection | Input sanitized or HTTP 403 Forbidden | Passed (Sanitized) | `evidence/defense/dvwa-sanitized.png` |
| **4** | **Endpoint Hardening** | `smbclient -L //192.168.20.25/ -N` | Connection refused / dropped | Passed (Refused) | `evidence/defense/smb-refused.png` |
| **5** | **Wazuh / Suricata Alerting** | Re-run Nmap scan & web injection attempts | Real-time alerts generated in Wazuh dashboard | Passed (Alerts Triggered) | `evidence/defense/wazuh-alerts.png` |

---

## Before vs. After Comparison

### Network Reachability:
* **Before:** Kali on Guest Wi-Fi could ping `192.168.20.10` and `192.168.20.25` with 0% packet loss.
* **After:** Kali on Guest Wi-Fi experiences 100% packet loss; pfSense logs explicitly show `DEFAULT_DENY` rule blocking `192.168.10.50 -> 192.168.20.0/24`.

### Web Security:
* **Before:** Remote command execution allowed exfiltration of `/etc/passwd`.
* **After:** Input sanitization prevents arbitrary command execution.

### Visibility & Detection:
* **Before:** Port scans and web attacks proceeded undetected with 0 alerts.
* **After:** Suricata and Wazuh log alerts with timestamp, attacker source IP, and signature descriptions.
