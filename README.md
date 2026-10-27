# SwagPc Café — Capstone (CIS 3353 Computer Systems Security)

Defending a small café against **guest-network compromise, web application attacks, and lateral movement**, following the **Build → Attack → Defend** pattern.

* **Course:** CIS 3353 Computer Systems Security · Dr. Gonzalo D. Parra
* **Commit approach:** **Individual Commits** *(unanimous team vote — declared on the proposal)*
* **Project board:** [GitHub Project Board](https://github.com/users/bash-y/projects) · **Wiki report:** [GitHub Wiki](https://github.com/bash-y/CIS_CapstoneProj_Swag01erload/wiki)
* **Live dashboard:** [bash-y.github.io/CIS_CapstoneProj_Swag01erload](https://bash-y.github.io/CIS_CapstoneProj_Swag01erload/) · progress, open PRs, milestones and commits, refreshed on every push to `main` and every 6 hours

---

## Scenario

**Organization:** *SwagPc Café* — a small coffee shop that provides free guest Wi-Fi while maintaining internal employee workstations and a Linux business server hosting a café web application.

**Threat:** An attacker connects to the café's guest network, discovers internal systems, accesses a vulnerable web application, and attempts to use that access to reach business resources because the initial environment is poorly segmented.

> A small café is vulnerable to unauthorized access and lateral movement from its public guest network. We will replicate this environment, demonstrate the attack against the **undefended** network using a vulnerable web application, and protect it by implementing network segmentation, firewall access controls, application security controls, endpoint hardening, and security monitoring. We will verify effectiveness by re-running the same attacks and confirming that unauthorized access is blocked, restricted, or detected.

---

## Build → Attack → Defend

**Build:** `swagpc-firewall` (Alpine/iptables — simulates pfSense) · `swagpc-kali` (attacker on Guest VLAN 10) · `swagpc-dvwa` (vulnerable café web portal on Business VLAN 20) · `swagpc-workstation` (simulated employee PC) · `swagpc-wazuh` (SIEM) · `swagpc-suricata` (IDS) — all 100% Docker, no VMs required.

**Attack (undefended):** guest-network reconnaissance · host discovery · service enumeration · access to internal DVWA application · controlled web application attack · attempted access toward business resources.

**Defend (with a test for each):**

| **Defense**                              | **Verification test**                                                               |
| ---------------------------------------- | ----------------------------------------------------------------------------------- |
| Guest/Business network segmentation      | Re-run host discovery from Guest → Business hosts should no longer be reachable     |
| pfSense firewall access controls         | Re-attempt Guest → Business connections → traffic should be denied + logged         |
| DVWA/application-layer security controls | Re-run the selected web attack → malicious request should be blocked/restricted     |
| Windows endpoint hardening               | Re-attempt unauthorized access → endpoint should deny/restrict access               |
| Wazuh/Suricata security monitoring       | Re-run reconnaissance/web attacks → relevant security events should generate alerts |

### Planned Network

```text
                         INTERNET
                             │
                         pfSense
                             │
              ┌──────────────┴──────────────┐
              │                             │
        GUEST NETWORK                  BUSINESS NETWORK
          VLAN 10                         VLAN 20
              │                             │
          Kali Linux                  Windows Employee PC
          Attacker                           │
              │                             │
              X                       Ubuntu Server
        Guest → Business                      │
              DENIED                         DVWA
                                             │
                                         Monitoring
```

The **undefended environment** will intentionally permit excessive communication between the Guest and Business networks so the attack can be demonstrated.

The **defended environment** will enforce segmentation and access-control rules.

Planned access policy:

```text
GUEST → INTERNET       ALLOW
GUEST → BUSINESS       DENY
GUEST → EMPLOYEE       DENY
GUEST → ADMIN          DENY

EMPLOYEE → SERVER      ALLOW
ADMIN → SERVER         ALLOW
SERVER → INTERNET      AS REQUIRED
```

Exact IP addresses, VLAN configuration, firewall rules, and services will be documented after implementation.

---

## Course Modules Integrated

| **Module**                                                        | **Where it appears**                                                                   |
| ----------------------------------------------------------------- | -------------------------------------------------------------------------------------- |
| **2 — Pervasive Attack Surfaces & Controls**                      | Guest network and web application as attack surfaces; reconnaissance; defense-in-depth |
| **5 — Endpoint Vulnerabilities, Attacks & Defenses**              | Windows employee workstation hardening and endpoint access controls                    |
| **8 — Infrastructure Threats & Security Monitoring**              | Security logging, attack detection, Wazuh/Suricata monitoring and alerts               |
| **9 — Infrastructure Security**                                   | pfSense firewall, VLANs, network segmentation, and access-control rules                |
| **10 — Wireless Network Attacks & Defenses** *(planned/optional)* | Guest Wi-Fi as the initial attack surface and wireless security controls               |

The project will count only modules whose concepts are **actually implemented and demonstrated** in the environment, not simply mentioned in the report.

The core planned integration is **Modules 2, 8, and 9**, with Modules 5 and 10 providing additional integration if implemented.

---

## Repository Structure

```text
/
├── README.md
│
├── configs/
│   ├── pfsense/
│   ├── firewall/
│   ├── endpoints/
│   ├── dvwa/
│   └── monitoring/
│
├── scripts/
│   ├── attack/
│   └── testing/
│
├── evidence/
│   ├── screenshots/
│   ├── logs/
│   ├── attack/
│   ├── defense/
│   └── test-results/
│
├── diagrams/
│   ├── initial-network.png
│   ├── secured-network.png
│   └── architecture.png
│
├── build/
│   ├── virtualization/
│   ├── network/
│   ├── server/
│   └── endpoints/
│
├── attack/
│   ├── reconnaissance/
│   ├── enumeration/
│   ├── dvwa/
│   └── lateral-movement/
│
├── defense/
│   ├── segmentation/
│   ├── firewall/
│   ├── application-security/
│   ├── endpoint-hardening/
│   └── monitoring/
│
├── testing/
│   ├── before-defense/
│   ├── after-defense/
│   └── results/
│
└── Wiki
    └── Final report
```

---

## Team & Roles

Roles are coordination hats — **every member does hands-on technical work**.

| **Member** | **GitHub** | **Role**                    |
| ---------- | ---------- | --------------------------- |
| Ant Huynh | [@UiwAntHuynhCIS](https://github.com/UiwAntHuynhCIS) | Project Lead |
| Sebastian Cadena | [@bash-y](https://github.com/bash-y) | System Architect |
| joromanii | [@joromanii](https://github.com/joromanii) | Security-Documentation Lead |

### Example technical responsibilities

**Project Lead**

* Coordinate project board and milestones
* Participate in firewall/segmentation implementation
* Participate in attack and verification testing

**System Architect**

* Design VM and network architecture
* Build virtual environment
* Configure servers and services
* Participate in attack/defense

**Security-Documentation Lead**

* Configure monitoring/security controls
* Develop verification tests
* Maintain technical evidence
* Participate in attack/defense

Roles do **not** eliminate technical responsibilities. No member should be documentation-only.

---

## Individual Contribution Summary Table

Contribution % = a member's story points ÷ team total story points. **This table must match the Project board** — discrepancies are investigated and the board wins. Update it as work completes.

| **Member**     | **Story points** | **Contribution %** | **Key contributions (link issues/PRs)**               |
| -------------- | ---------------: | -----------------: | ----------------------------------------------------- |
| Ant Huynh (`@UiwAntHuynhCIS`) | 18 | 33.3% | #42 US-1 Setup, #44 US-3 pfSense Dual-VLAN Architecture, #49 US-8 pfSense Segmentation, #53 US-12 Docs & Evidence |
| Sebastian Cadena (`@bash-y`) | 18 | 33.3% | #43 US-2 Proposal & Topology, #45 US-4 Business Server & PC, #50 US-9 Windows Endpoint Hardening, #54 US-13 Presentation & Demo |
| joromanii (`@joromanii`) | 18 | 33.3% | #46 US-5 DVWA & Kali Attacker, #47 US-6 Reconnaissance, #48 US-7 Web Exploit & Pivot, #51 US-10 App Security, #52 US-11 Wazuh Monitoring |
| **Team total** | **54** | **100%** | Backlog balanced across 13 User Stories (#42–#54) |

**Story points:** 1, 2, 3, 5, or 8 only.

Tasks underneath stories should use **XS, S, M, L, or XL**, not story points.

---

## Core Attack/Defense Demonstration

The final presentation should tell one continuous story:

```text
BEFORE
   ↓
Customer connects to SwagPc Café Guest Wi-Fi
   ↓
ATTACK
   ↓
Kali performs reconnaissance
   ↓
Internal web server discovered
   ↓
DVWA discovered
   ↓
Controlled web attack demonstrated
   ↓
Attempted access toward business resources
   ↓
Attack evidence captured
   ↓
DEFEND
   ↓
Segmentation + Firewall
Application Security
Endpoint Hardening
Monitoring
   ↓
AFTER
   ↓
Repeat the SAME attack
   ↓
Traffic blocked / access restricted
   ↓
Security event detected
   ↓
Compare BEFORE vs AFTER
