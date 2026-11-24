# SwagPc Café — Security Capstone Project

Welcome to the **SwagPc Café** Capstone Wiki for **CIS 3353: Computer Systems Security** (Dr. Gonzalo D. Parra).

## Project Overview

* **Organization:** *SwagPc Café* — a small coffee shop providing free public guest Wi-Fi while operating internal business workstations and a Linux server running the café's web portal.
* **Core Vulnerability:** A flat, unsegmented network allows untrusted guests on the public Wi-Fi to discover internal business hosts, exploit a vulnerable web application, and pivot laterally toward sensitive employee workstations.
* **Planned defenses:** pfSense segmentation between Guest VLAN 10 and Business VLAN 20, Windows endpoint hardening, application controls, and Suricata/Wazuh monitoring. The Docker lab models the network segments with bridges and uses Alpine containers for the router and workstation. See [[Network Architecture & IP Plan|Architecture]] for platform evidence and outstanding rubric decisions.
* **Methodology:** Strict **Build → Attack → Defend** lifecycle with verifiable before-and-after tests.

---

## Wiki Navigation

1. [[Project Proposal|Proposal]] — Problem statement, threat model, course modules, and commit approach.
2. [[Network Architecture & IP Plan|Architecture]] — Detailed VLAN layout, routing policies, and system topology.
3. [[Environment Build Guide|Build]] — Lab build instructions and planned platform requirements.
4. [[Undefended Attack Demonstration|Attack]] — Guest network reconnaissance, DVWA web exploitation, and lateral pivot evidence.
5. [[Defense Implementation|Defense]] — Segmentation policy, endpoint hardening, and monitoring configuration.
6. [[Testing & Verification|Testing-and-Verification]] — Repeat-attack tests proving attacks are blocked, sanitized, or alerted.
7. [[Team Contribution Log|Contribution-Log]] — Individual story points, task breakdowns, and board mapping.
8. [[Discord Update Bot|Discord-Bot]] — Commit, pull request, issue and CI alerts plus daily/weekly digests in Discord.
9. [[Discord PR Bot|Discord-PR-Bot]] — Approve and merge pull requests from Discord, recorded under each teammate's own GitHub account.

---

## Team Roster

| Member | GitHub Handle | Role | Assigned Story Points |
|---|---|---|---|
| **Ant Huynh** | `@UiwAntHuynhCIS` | Project Lead | 29 pts (31.5%) |
| **Sebastian Cadena** | `@bash-y` | System Architect | 36 pts (39.1%) |
| **joromanii** | `@joromanii` | Security-Documentation Lead | 27 pts (29.3%) |

*Commit Approach:* **Individual Commits** (Unanimously declared on proposal).
