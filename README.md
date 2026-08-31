# SecureClinic — Capstone (CIS 3353 Computer Systems Security)

Defending a small medical clinic against credential attacks and network intrusion, following the **Build → Attack → Defend** pattern.

- **Course:** CIS 3353 Computer Systems Security · Dr. Gonzalo D. Parra
- **Commit approach:** Individual Commits *(unanimous team vote — declared on the proposal)*
- **Project board:** _add link_ · **Wiki report:** _add link_

---

## Scenario

**Organization:** *Cedar Valley Family Clinic* — a ~15-person medical clinic with an on-prem Windows domain, clinical workstations holding PHI, and an internet-facing patient portal.

**Threat:** An attacker steals a staff credential, escalates inside Active Directory (password spray + Kerberoasting), and exploits the internet-facing patient portal (SQL injection), then pivots from the DMZ into the clinical LAN because the network is flat.

> A small medical clinic is vulnerable to credential-based attacks and network intrusion. We replicate this environment, demonstrate the attack, and then protect it by implementing network segmentation, Active Directory / IAM hardening, and a web application firewall plus IDS/SIEM monitoring. We verify effectiveness by re-running each attack and confirming it is blocked, denied, or alerted.

---

## Build → Attack → Defend

**Build:** pfSense firewall (WAN / LAN / DMZ) · Windows Server 2022 AD DC (`clinic.local`) · Windows 10/11 domain workstation · Linux web server with vulnerable patient portal (DVWA/Juice Shop) · Kali Linux attacker · all on virtual networks.

**Attack (undefended):** password spray · Kerberoasting · SQL injection with data exfiltration · DMZ→LAN lateral movement.

**Defend (with a test for each):**

| Defense | Verification test |
|---|---|
| pfSense segmentation (DMZ → LAN deny) | Re-attempt DMZ→LAN connection → blocked + logged |
| AD hardening: GPO password/lockout, LAPS, Kerberos hardening | Re-run spray → lockout fires; re-run Kerberoast → crack fails |
| ModSecurity WAF (OWASP CRS) | Re-run SQLi → HTTP 403, no data, logged |
| Suricata IDS + Wazuh SIEM | Re-run attacks → alerts fire in Wazuh |

---

## Course Modules Integrated

| Module | Where it appears |
|---|---|
| 2 — Pervasive Attack Surfaces & Controls | Attack-surface enumeration; defense-in-depth |
| 7 — IAM | AD, credential attacks, password/lockout GPO, LAPS, Kerberos hardening |
| 8 — Infrastructure Threats & Security Monitoring | Suricata IDS + Wazuh SIEM |
| 9 — Infrastructure Security | pfSense firewall, DMZ, segmentation |

---

## Repository Structure

```
/                     README (this file)
/configs              firewall rules, GPO exports, ModSecurity/Suricata/Wazuh configs
/scripts              attack + test scripts
/evidence             screenshots, logs, test output
/diagrams             network + architecture diagrams
Wiki                  final report (Build / Attack / Defend, with evidence)
```

---

## Team & Roles

Roles are coordination hats — **every member does hands-on technical work**.

| Member | GitHub | Role |
|---|---|---|
| _Name_ | _@handle_ | Project Lead |
| _Name_ | _@handle_ | System Architect |
| _Name_ | _@handle_ | Security-Documentation Lead |

---

## Individual Contribution Summary Table

Contribution % = a member's story points ÷ team total story points. **This table must match the Project board** — discrepancies are investigated and the board wins. Update it as work completes.

| Member | Story points | Contribution % | Key contributions (link issues/PRs) |
|---|---|---|---|
| _Name_ | _0_ | _0%_ | _e.g. #12 pfSense segmentation, #18 Suricata rules_ |
| _Name_ | _0_ | _0%_ | |
| _Name_ | _0_ | _0%_ | |
| **Team total** | **_0_** | **100%** | |
