# Project Proposal

## 1. Scenario & Threat

**Organization:** *SwagPc Café* — a small coffee shop that provides free guest Wi-Fi while maintaining internal employee workstations and a Linux business server hosting a café web application.

**Threat:** An attacker connects to the café's guest network, discovers internal systems due to a flat network design, accesses a vulnerable web application, and attempts to use that access to reach business resources.

### Proposal Brainstorm Sentence
> "A **small café with public guest Wi-Fi** is vulnerable to **unauthorized network reconnaissance, web application exploitation, and lateral movement into business operations**. We will replicate this environment, demonstrate the attack on an undefended flat network (reconnaissance, DVWA exploitation, and unauthorized access to business resources), and protect it by implementing **(1) network segmentation with pfSense (Guest VLAN 10 vs. Business VLAN 20)**, **(2) application-layer security hardening**, **(3) endpoint hardening on Windows workstations**, and **(4) intrusion detection and security monitoring (Suricata + Wazuh)**. We will verify effectiveness by **re-running each attack and proving it is blocked, denied, or alerted, capturing logs and screenshots as evidence**."

---

## 2. Course Modules Integrated

| Module | Where It Appears in Project |
|---|---|
| **Module 2 — Pervasive Attack Surfaces & Controls** | Guest network and web application attack surfaces; defense-in-depth posture |
| **Module 5 — Endpoint Vulnerabilities, Attacks & Defenses** | Windows workstation local firewall policies, least-privilege configuration, disabled legacy protocols |
| **Module 8 — Infrastructure Threats & Security Monitoring** *(core)* | Suricata IDS signature inspection and Wazuh SIEM security event log analysis |
| **Module 9 — Infrastructure Security** *(core)* | pfSense firewall, dual-VLAN segmentation (VLAN 10 Guest vs VLAN 20 Business), strict packet filtering |

---

## 3. Declared Commit Approach

* **Approach Selected:** **Individual Commits**
* **Vote:** Unanimous team agreement
* **Policy:** Each member works on their assigned user stories and subtasks, committing and pushing directly from their personal GitHub account to ensure clear attribution and verifiable individual grades.
