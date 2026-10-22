# CIS 3353 Capstone Plan
## SwagPc Café — Defending Against Guest-Network Compromise, Web Application Attacks, and Lateral Movement

> Dates are intentionally relative (sprints/weeks). The real due dates live on Canvas — map each milestone to the posted Canvas deadline before you commit to the board.

---

## 1. The Project Idea

**Organization:** *SwagPc Café* — a small coffee shop offering free public guest Wi-Fi while maintaining internal employee business workstations and an on-premise Linux server hosting a café web application (ordering & management).

**Threat:** An attacker connects to the café's guest network, discovers internal business hosts due to a flat/unsegmented network, exploits a vulnerable café web application (command injection / SQL injection on DVWA), and pivots toward business workstations and administrative resources.

### Brainstorm Sentence (proposal-ready)
> "A **small café with public guest Wi-Fi** is vulnerable to **unauthorized network reconnaissance, web application exploitation, and lateral movement into business operations**. We will replicate this environment, demonstrate the attack on an undefended flat network (reconnaissance, DVWA exploitation, and unauthorized access to business resources), and protect it by implementing **(1) network segmentation with pfSense (Guest VLAN 10 vs. Business VLAN 20)**, **(2) application-layer security hardening**, **(3) endpoint hardening on Windows workstations**, and **(4) intrusion detection and security monitoring (Suricata + Wazuh)**. We will verify effectiveness by **re-running each attack and proving it is blocked, denied, or alerted, capturing logs and screenshots as evidence**."

### Build → Attack → Defend

**BUILD (the environment):**
- **pfSense firewall/router** — zones: WAN, Guest Network (VLAN 10), Business Network (VLAN 20)
- **Linux Web Server (Ubuntu)** — hosting the café web application (DVWA containerized via Docker)
- **Windows Employee PC** — business workstation connected to the business network
- **Kali Linux attacker VM** — positioned on the guest network
- **Virtual networks / Docker bridges** — isolating Guest and Business segments with configurable routing

**ATTACK (before any defenses — undefended baseline demo):**
- Guest network reconnaissance: ARP scanning, Nmap ping sweep, and service enumeration discovering business systems
- Web exploitation: Attacking DVWA on the web server from the guest network
- Lateral movement: Demonstrating traffic reaching the employee workstation and business server from the guest network

**DEFEND (implement, then test each one):**
| Defense | Test that proves it works |
|---|---|
| pfSense segmentation (Guest VLAN 10 → Business VLAN 20 DENY) | Re-run host discovery/ping from Guest → Business hosts unreachable + firewall logs drop |
| pfSense firewall access controls | Re-attempt direct connection to business services → connection denied + logged |
| DVWA / Web application hardening (input validation, restricted access) | Re-run web exploit → HTTP 403 / payload sanitized, attack fails |
| Windows endpoint hardening (firewall rules, disabled insecure protocols) | Re-attempt unauthorized network access against employee PC → connection rejected |
| Suricata IDS + Wazuh SIEM monitoring | Re-run attacks → alerts triggered in Wazuh dashboard with corresponding logs |

### Modules Integrated
| Module | Where it shows up |
|---|---|
| **2 — Pervasive Attack Surfaces & Controls** | Guest Wi-Fi & web application as initial attack surfaces; defense-in-depth architecture |
| **5 — Endpoint Vulnerabilities, Attacks & Defenses** | Windows employee workstation hardening, local firewall policies, least-privilege controls |
| **8 — Infrastructure Threats & Security Monitoring** *(core)* | Suricata IDS network signatures + Wazuh SIEM log collection and alert generation |
| **9 — Infrastructure Security** *(core)* | pfSense firewall, VLAN segmentation (VLAN 10 Guest vs VLAN 20 Business), access rules |
| **10 — Wireless Network Attacks & Defenses** *(optional/context)* | Public guest Wi-Fi isolation and rogue access mitigation concepts |

### Declared Commit Approach
**Individual Commits** — Each member commits and pushes their own assigned work from their respective GitHub account. Story points follow the individual contributor, maintaining clean accountability and verifying individual effort on the contribution board. *(Unanimously approved by team)*.

---

## 2. Milestones

| # | Milestone | "Done" means | Target |
|---|---|---|---|
| **M1** | **Proposal Approved** | Repo, board, and wiki are live; proposal signed off by instructor | End of Sprint 1 |
| **M2** | **Environment Built & Attack Demonstrated** | VMs/containers & virtual networks up; undefended attacks proven & evidenced | End of Sprint 3 |
| **M3** | **Defenses Implemented & Verified** | Segmentation, endpoint hardening, and monitoring in place; all defense verification tests pass | End of Sprint 5 |
| **M4** | **Documentation & Presentation** | Wiki report complete with before/after evidence; slide deck ready; demo dry-run complete | End of Sprint 6 |

---

## 3. Team Roster & Allocation

| Code | Team Member | GitHub Handle | Primary Role |
|---|---|---|---|
| **A** | **Ant Huynh** | `@UiwAntHuynhCIS` | Project Lead |
| **B** | **Sebastian Cadena** | `@bash-y` | System Architect |
| **C** | **joromanii** | `@joromanii` | Security-Documentation Lead |

*Note: Roles are coordination hats; all members complete hands-on technical work.*

---

## 4. User Stories, Tasks, and Points

- **Story points (1, 2, 3, 5)** live **only on user stories** (no story exceeds 5 points).
- **Sizes (XS, S, M, L, XL)** live **only on subtasks**.
- Backlog is balanced: **18 points per team member** (54 points total, 33.3% contribution each).

### Milestone 1 — Proposal Approved

**US-1 (#42) (3 pts) — As a team, we want a configured private repo, board, and wiki so that our project is tracked from day one.** *(Sprint 1)*
- [ ] Create private repository; add collaborators `gdparra-edu` and `cyberknowledge` — *XS* — **A**
- [ ] Enable Wiki; initialize Home page and documentation structure — *XS* — **C**
- [ ] Create GitHub Project board with Iterative Development template and 2-week iterations — *S* — **A**
- [ ] Create the four milestones (M1–M4) in the GitHub repository — *XS* — **B**
- [ ] Finalize README with team roster, roles, and Individual Contribution Summary Table — *S* — **C**

**US-2 (#43) (3 pts) — As a team, we want an approved proposal so that we have formal instructor sign-off to proceed.** *(Sprint 1)*
- [ ] Draft scenario, brainstorm sentence, and problem statement for SwagPc Café — *S* — **B**
- [ ] Diagram initial vs. segmented network topology (WAN/pfSense/Guest VLAN 10/Business VLAN 20) — *M* — **A**
- [ ] Map course modules (Modules 2, 5, 8, 9) to specific café infrastructure and defenses — *S* — **C**
- [ ] Define the test verification criteria and metrics for each defense — *S* — **B**

---

### Milestone 2 — Environment Built & Attack Demonstrated

**US-3 (#44) (5 pts) — As a system architect, I want a dual-network pfSense environment so that the café guest and business networks are realistically replicated.** *(Sprint 2)*
- [ ] Deploy pfSense firewall router with WAN, Guest (VLAN 10), and Business (VLAN 20) interfaces — *M* — **A**
- [ ] Configure Docker networks / hypervisor virtual bridges (`guest-net` and `business-net`) — *S* — **B**
- [ ] Document IP addressing scheme, subnets, and routing table — *S* — **C**
- [ ] Perform baseline reachability test across subnets in the undefended state — *S* — **A**

**US-4 (#45) (5 pts) — As a systems administrator, I want café business endpoints deployed so that target business resources exist.** *(Sprint 2)*
- [ ] Deploy Ubuntu Linux server VM hosting business services — *M* — **B**
- [ ] Deploy Windows employee workstation VM on the business network — *M* — **A**
- [ ] Configure employee accounts and sample business data/files on the workstation — *S* — **C**
- [ ] Verify employee workstation connectivity to the business server — *XS* — **B**

**US-5 (#46) (3 pts) — As a web administrator, I want the café web application and attacker node deployed so that the attack surface is active.** *(Sprint 2)*
- [ ] Deploy DVWA container on the Linux server representing the café web portal — *S* — **B**
- [ ] Deploy Kali Linux VM/container connected directly to the guest network — *S* — **C**
- [ ] Confirm Kali can reach the DVWA application across the undefended network — *XS* — **C**

**US-6 (#47) (5 pts) — As a penetration tester, I want to conduct guest-network reconnaissance against the undefended network so that exposure is proven.** *(Sprint 3)*
- [ ] Execute ARP scan and Nmap discovery from Kali across the café network — *M* — **C**
- [ ] Enumerate open ports and services on the business server and employee workstation — *M* — **B**
- [ ] Document and capture screenshots/command outputs of all exposed business assets — *S* — **A**

**US-7 (#48) (5 pts) — As a penetration tester, I want to exploit the café web application and demonstrate lateral movement so that business risk is proven.** *(Sprint 3)*
- [ ] Execute web exploit (command injection / SQLi) on DVWA from the guest position — *M* — **C**
- [ ] Attempt lateral ping and service connection from guest position toward employee PC — *M* — **A**
- [ ] Capture all before-defense attack evidence, logs, and screenshots — *S* — **B**

---

### Milestone 3 — Defenses Implemented & Verified

**US-8 (#49) (5 pts) — As a network security engineer, I want pfSense firewall segmentation so that guest traffic cannot reach business assets.** *(Sprint 4)*
- [ ] Configure pfSense firewall rules: `GUEST -> BUSINESS` DENY and LOG — *S* — **A**
- [ ] Configure rule: `GUEST -> INTERNET` ALLOW (captive/isolated guest access) — *S* — **A**
- [ ] Configure rule: `BUSINESS -> INTERNET` and `EMPLOYEE -> SERVER` ALLOW — *S* — **B**
- [ ] **Verification Test:** Re-run Nmap and ping from Kali on Guest to Business; verify packets dropped and logged — *M* — **C**

**US-9 (#50) (5 pts) — As an endpoint security engineer, I want endpoint defenses configured on the business workstation so that unauthorized access is blocked.** *(Sprint 4)*
- [ ] Configure Windows Defender Firewall rules to restrict incoming connections to authorized subnets — *S* — **B**
- [ ] Disable unneeded legacy protocols (NetBIOS, LLMNR, SMBv1) on the employee PC — *S* — **A**
- [ ] Implement local account least-privilege and password policies — *S* — **B**
- [ ] **Verification Test:** Re-attempt direct connection/access to employee PC from guest node; verify connection rejected — *M* — **C**

**US-10 (#51) (3 pts) — As an application security engineer, I want web application defenses implemented so that web exploits are mitigated.** *(Sprint 5)*
- [ ] Harden DVWA security settings (increase security level to High/Impossible or implement input sanitization) — *S* — **C**
- [ ] Implement reverse proxy / web application access controls restricting web portal management — *S* — **B**
- [ ] **Verification Test:** Re-run identical web exploit payloads; verify HTTP 403 or sanitized responses with logs — *M* — **A**

**US-11 (#52) (5 pts) — As a SOC analyst, I want Suricata IDS and Wazuh SIEM deployed so that network and endpoint attacks generate alerts.** *(Sprint 5)*
- [ ] Deploy Suricata IDS monitoring traffic across the network interfaces — *M* — **A**
- [ ] Deploy Wazuh manager and configure Wazuh agents on the Linux server and Windows PC — *M* — **C**
- [ ] Configure custom alert rules for reconnaissance scans and web exploitation attempts — *S* — **B**
- [ ] **Verification Test:** Re-run attack sequence; capture Wazuh dashboard alerts and log entries demonstrating detection — *M* — **B**

---

### Milestone 4 — Documentation & Presentation

**US-12 (#53) (4 pts) — As a documentation lead, I want a comprehensive Wiki report with before-and-after evidence so that the capstone is fully documented.** *(Sprint 6)*
- [ ] Compile complete Build, Attack, and Defend sections in the GitHub Wiki — *M* — **C**
- [ ] Format before vs. after side-by-side comparison tables, screenshots, and log snippets — *M* — **A**
- [ ] Cross-check that the README contribution table matches the GitHub Project board exactly — *S* — **B**

**US-13 (#54) (3 pts) — As a team, we want a polished presentation slide deck and rehearsed demo so that our final presentation succeeds.** *(Sprint 6)*
- [ ] Create capstone presentation slide deck covering scenario, attack, defense, and outcomes — *S* — **B**
- [ ] Script and rehearse the live/recorded demonstration video backup — *S* — **A**
- [ ] Conduct full team dry-run rehearsal — *S* — **C**

---

## 5. Story Points Balance Summary

| Team Member | GitHub | Assigned Stories | Total Points | % Contribution |
|---|---|---|---|---|
| **Ant Huynh** | `@UiwAntHuynhCIS` | US-1 (3), US-3 (5), US-8 (5), US-12 (partial / 5) | **18 pts** | **33.3%** |
| **Sebastian Cadena** | `@bash-y` | US-2 (3), US-4 (5), US-9 (5), US-13 (partial / 5) | **18 pts** | **33.3%** |
| **joromanii** | `@joromanii` | US-5 (3), US-6 (5), US-7 (5), US-10 (partial / 5) | **18 pts** | **33.3%** |
| **Total Team Backlog** | | **13 User Stories** | **54 pts** | **100%** |

---

## 6. Sprint Schedule (6 Sprints × 2 Weeks)

| Sprint | Timeline | Primary Objective | User Stories | Target Milestone |
|---|---|---|---|---|
| **Sprint 1** | Weeks 1–2 | Project Setup, Proposal Sign-off, Topology Design | US-1, US-2 | **M1: Proposal Approved** |
| **Sprint 2** | Weeks 3–4 | Environment Build: pfSense, Networks, DVWA, Workstation | US-3, US-4, US-5 | — |
| **Sprint 3** | Weeks 5–6 | Undefended Attacks: Reconnaissance, DVWA Exploit, Evidence | US-6, US-7 | **M2: Build & Attack Demo** |
| **Sprint 4** | Weeks 7–8 | Defenses Part 1: pfSense Segmentation & Endpoint Hardening | US-8, US-9 | — |
| **Sprint 5** | Weeks 9–10 | Defenses Part 2: App Hardening, Wazuh/Suricata & Verification | US-10, US-11 | **M3: Defenses Verified** |
| **Sprint 6** | Weeks 11–12 | Wiki Report Finalization, Slide Deck, Demo Rehearsal | US-12, US-13 | **M4: Docs & Presentation** |
| **Buffer** | Finals Week | Freeze Wiki, Freeze Board, Deliver Capstone Presentation | — | **Final Submission** |
