# SwagPc Café — Security Capstone Project

Welcome to the **SwagPc Café** Capstone Wiki for **CIS 3353: Computer Systems Security** (Dr. Gonzalo D. Parra).

## Project Overview

* **Organization:** *SwagPc Café* — a small coffee shop providing free public guest Wi-Fi while operating internal business workstations and a Linux server running the café's web portal.
* **Core Vulnerability:** A flat, unsegmented network allows untrusted guests on the public Wi-Fi to discover internal business hosts, exploit a vulnerable web application, and pivot laterally toward sensitive employee workstations.
* **Core Defense:** Network segmentation and firewall access controls using **pfSense** (VLAN 10 Guest vs. VLAN 20 Business), application-layer security hardening, Windows endpoint hardening, and security monitoring via **Suricata IDS + Wazuh SIEM**.
* **Methodology:** Strict **Build → Attack → Defend** lifecycle with verifiable before-and-after tests.

---

## Wiki Navigation

1. [[Project Proposal|Proposal]] — Problem statement, threat model, course modules, and commit approach.
2. [[Network Architecture & IP Plan|Architecture]] — Detailed VLAN layout, routing policies, and system topology.
3. [[Environment Build Guide|Build]] — Step-by-step setup of pfSense, Docker networks, DVWA, and endpoints.
4. [[Undefended Attack Demonstration|Attack]] — Guest network reconnaissance, DVWA web exploitation, and lateral pivot evidence.
5. [[Defense Implementation|Defense]] — pfSense segmentation rules, endpoint hardening, and monitoring deployment.
6. [[Testing & Verification|Testing-and-Verification]] — Repeat-attack tests proving attacks are blocked, sanitized, or alerted.
7. [[Team Contribution Log|Contribution-Log]] — Individual story points, task breakdowns, and board mapping.
8. [[Discord Update Bot|Discord-Bot]] — Commit, pull request, issue and CI alerts plus daily/weekly digests in Discord.

---

## Team Roster

| Member | GitHub Handle | Role | Assigned Story Points |
|---|---|---|---|
| **Ant Huynh** | `@UiwAntHuynhCIS` | Project Lead | 18 pts (33.3%) |
| **Sebastian Cadena** | `@bash-y` | System Architect | 18 pts (33.3%) |
| **joromanii** | `@joromanii` | Security-Documentation Lead | 18 pts (33.3%) |

*Commit Approach:* **Individual Commits** (Unanimously declared on proposal).
