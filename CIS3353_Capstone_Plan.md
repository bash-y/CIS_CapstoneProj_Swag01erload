# CIS 3353 Capstone Plan
## SecureClinic — Defending a Small Medical Clinic Against Credential Attacks and Network Intrusion

> Dates are intentionally relative (sprints/weeks). The real due dates live on Canvas — map each milestone to the posted Canvas deadline before you commit to the board.

---

## 1. The Project Idea

**Organization:** *Cedar Valley Family Clinic* — a ~15-person medical clinic running an on-prem Windows domain, clinical workstations that hold patient health information (PHI), and an internet-facing patient portal. Realistic setting, clearly something worth protecting.

**Threat:** An attacker steals a staff credential, escalates inside Active Directory (password spray + Kerberoasting), and separately exploits the internet-facing patient portal (SQL injection), then pivots from the DMZ into the clinical LAN because the network is flat.

### Brainstorm Sentence (proposal-ready)
> "A **small medical clinic** is vulnerable to **credential-based attacks and network intrusion**. We will replicate this environment, demonstrate the attack (password spray, Kerberoasting, and a SQL-injection web exploit that pivots into the clinical LAN), and then protect it by implementing **(1) network segmentation with a pfSense firewall**, **(2) Active Directory / IAM hardening (GPO password policy, account lockout, LAPS, Kerberos hardening)**, and **(3) a web application firewall plus IDS/SIEM monitoring (ModSecurity + Suricata + Wazuh)**. We will verify effectiveness by **re-running each attack and confirming it is blocked, denied, or alerted, with logs and screenshots as evidence**."

### Build → Attack → Defend

**BUILD (the environment):**
- pfSense firewall/router — zones: WAN, LAN (clinical), DMZ (patient portal)
- Windows Server 2022 → Active Directory Domain Controller (`clinic.local`)
- Windows 10/11 workstation joined to the domain
- Linux web server hosting a deliberately vulnerable patient portal (DVWA or OWASP Juice Shop as a stand-in)
- Kali Linux attacker VM (external + internal positions)
- All on VirtualBox/VMware with internal virtual networks

**ATTACK (before any defenses — this demo is required, don't skip it):**
- Password spray against AD accounts (weak policy)
- Kerberoast a service account, crack the hash offline
- SQL injection against the portal to exfiltrate "patient" data
- Show the DMZ web host can reach the clinical LAN (lateral movement)

**DEFEND (implement, then test each one):**
| Defense | Test that proves it works |
|---|---|
| pfSense segmentation (DMZ → LAN deny) | Re-attempt DMZ→LAN connection → blocked + logged |
| AD hardening: GPO password/lockout policy, LAPS, Kerberos hardening | Re-run spray → lockout fires; re-run Kerberoast → crack fails |
| ModSecurity WAF (OWASP CRS) on the portal | Re-run SQLi → HTTP 403, no data returned, logged |
| Suricata IDS + Wazuh SIEM | Re-run all attacks → alerts fire in Wazuh dashboard |

### Modules Integrated (4 — the floor is 3)
| Module | Where it shows up |
|---|---|
| **2 — Pervasive Attack Surfaces & Controls** | Attack-surface enumeration; defense-in-depth control choices |
| **7 — IAM** *(core)* | AD, credential attacks, password/lockout GPO, LAPS, Kerberos hardening |
| **8 — Infrastructure Threats & Security Monitoring** *(core)* | Suricata IDS + Wazuh SIEM detection and alerting |
| **9 — Infrastructure Security** *(core)* | pfSense firewall, DMZ, network segmentation |
| *(Optional 5th)* **12 — Vulnerability Management** | Scan the portal, track/remediate findings |

### Recommended Commit Approach
**Individual Commits** — each member pushes their own work; points follow the committer. This protects each contributor and is the safe default. (Delegated Commits only if you fully trust one person to push everyone's real work.) Whatever you pick must be a **unanimous vote declared on the proposal**.

---

## 2. Milestones

Create these in the repo **before** writing any issues. Rename to fit your scenario if you like.

| # | Milestone | "Done" means | Target |
|---|---|---|---|
| M1 | **Proposal Approved** | Repo, board, and wiki are live; proposal signed off by instructor | End of Sprint 1 |
| M2 | **Environment Built & Attack Demonstrated** | VMs + virtual networks up; all attacks proven against the undefended build | End of Sprint 3 |
| M3 | **Defenses Implemented & Verified** | All controls in place; every defense has a passing test | End of Sprint 5 |
| M4 | **Documentation & Presentation** | Wiki report complete; demo dry-run done | End of Sprint 6 |

---

## 3. User Stories, Tasks, and Points

**Rules baked in below:**
- Story points (1, 2, 3, 5, 8) live **only on user stories**. No 8s (an 8 is too big — already split).
- Sizes (XS, S, M, L, XL) live **only on tasks**.
- Every issue gets **both** a Milestone and an Iteration when you load it on the board.
- Assignees are shown as A / B / C — spread so **everyone does technical work** (no documentation-only member).

### Milestone 1 — Proposal Approved

**US-1 (3 pts) — As a team, we want a configured private repo, board, and wiki so that our work is tracked from day one.**
- [ ] Create private repo; add collaborators `gdparra-edu` and `cyberknowledge` — *XS* — A
- [ ] Enable Wiki; create Home page skeleton — *XS* — C
- [ ] Create Project board from Iterative Development template, 2-week iterations — *S* — A
- [ ] Create the four milestones in the repo — *XS* — B
- [ ] Add README with the Individual Contribution Summary Table — *S* — C

**US-2 (3 pts) — As a team, we want an approved proposal so that we can start building with instructor sign-off.**
- [ ] Draft brainstorm sentence + organization/threat scenario — *S* — B
- [ ] Diagram the target network topology (WAN/LAN/DMZ) — *M* — A
- [ ] Map the 3+ modules to specific build/defense items — *S* — C
- [ ] Define the test method for each defense — *S* — B

### Milestone 2 — Environment Built & Attack Demonstrated

**US-3 (5 pts) — As a system architect, I want a segmented virtual network with pfSense so that the clinic topology is realistically replicated.**
- [ ] Install pfSense VM; configure WAN/LAN/DMZ interfaces — *M* — A
- [ ] Create the internal virtual networks in the hypervisor — *S* — A
- [ ] Document the IP addressing plan — *S* — C
- [ ] Baseline connectivity test across zones — *S* — B

**US-4 (5 pts) — As a system administrator, I want an Active Directory domain with users and a service account so that credential attacks can be demonstrated.**
- [ ] Install Windows Server 2022; promote to Domain Controller — *M* — B
- [ ] Create OUs, users, and groups — *S* — B
- [ ] Create a Kerberoastable service account (SPN set) — *S* — B
- [ ] Join a Windows 10/11 workstation to the domain — *M* — A

**US-5 (3 pts) — As a web administrator, I want the patient portal deployed in the DMZ so that a web exploit can be demonstrated.**
- [ ] Deploy Linux web VM with vulnerable app (DVWA/Juice Shop) — *M* — C
- [ ] Place in DMZ; expose through pfSense — *S* — A
- [ ] Confirm reachable from the Kali/WAN position — *S* — C

**US-6 (5 pts) — As a penetration tester, I want to demonstrate credential attacks against undefended AD so that the threat is proven before defenses.**
- [ ] Password spray with kerbrute / CrackMapExec — *M* — B
- [ ] Kerberoast a service account; crack with hashcat — *M* — B
- [ ] Capture screenshots + logs as evidence — *S* — C

**US-7 (5 pts) — As a penetration tester, I want to exploit the portal and pivot so that lateral-movement risk is proven.**
- [ ] SQL injection to exfiltrate "patient" data — *M* — C
- [ ] Demonstrate DMZ→LAN reachability from the web host — *S* — A
- [ ] Capture evidence of the pivot — *S* — B

### Milestone 3 — Defenses Implemented & Verified

**US-8 (5 pts) — As a network engineer, I want firewall segmentation so that a compromised DMZ host cannot reach the clinical LAN.**
- [ ] Write pfSense rules: DMZ→LAN deny — *S* — A
- [ ] Allow only required flows (least privilege) — *S* — A
- [ ] **Test:** re-attempt DMZ→LAN, confirm blocked + logged — *M* — B

**US-9 (5 pts) — As an identity administrator, I want AD hardened so that credential attacks fail.**
- [ ] GPO: strong password + account lockout policy — *S* — B
- [ ] Deploy LAPS for local admin passwords — *M* — B
- [ ] Harden service account / Kerberos encryption — *S* — A
- [ ] **Test:** re-run spray + Kerberoast, confirm failure — *M* — C

**US-10 (3 pts) — As a security engineer, I want a WAF in front of the portal so that web exploits are blocked.**
- [ ] Install ModSecurity + OWASP Core Rule Set — *M* — C
- [ ] Tune rules to the app — *S* — C
- [ ] **Test:** re-run SQLi, confirm 403 + logged — *S* — A

**US-11 (5 pts) — As a SOC analyst, I want IDS + SIEM monitoring so that attacks raise alerts.**
- [ ] Deploy Suricata on the perimeter — *M* — A
- [ ] Deploy Wazuh manager + agents — *M* — C
- [ ] Build detection rules (spray / Kerberoast / web attack) — *M* — B
- [ ] **Test:** re-run all attacks, confirm alerts fire — *M* — C

### Milestone 4 — Documentation & Presentation

**US-12 (3 pts) — As a documentation lead, I want a complete wiki report so that the work is fully evidenced.**
- [ ] Write Build/Attack/Defend sections with screenshots — *M* — C
- [ ] Add architecture diagram + module mapping — *S* — A
- [ ] Verify README contribution table matches the board — *S* — B

**US-13 (3 pts) — As a team, we want a rehearsed presentation so that the demo runs smoothly on presentation day.**
- [ ] Build the slide deck — *S* — B
- [ ] Prepare the live demo flow / recording backup — *S* — A
- [ ] Full dry-run — *S* — C

**Backlog total: 58 story points across 13 stories.**

---

## 4. Timeline (6 sprints × 2 weeks)

Set the actual iteration dates to match the Canvas schedule. Each sprint is one Iteration on the board.

| Sprint | Weeks | Focus | Stories | Closes |
|---|---|---|---|---|
| Sprint 1 | 1–2 | Team setup, repo/board/wiki, proposal | US-1, US-2 | **M1** |
| Sprint 2 | 3–4 | Build environment (pfSense, AD, portal) | US-3, US-4, US-5 | — |
| Sprint 3 | 5–6 | Undefended attack demos | US-6, US-7 | **M2** |
| Sprint 4 | 7–8 | Segmentation + AD hardening | US-8, US-9 | — |
| Sprint 5 | 9–10 | WAF + monitoring + verification | US-10, US-11 | **M3** |
| Sprint 6 | 11–12 | Wiki report + presentation prep & dry-run | US-12, US-13 | **M4** |
| Buffer | 13+ | Freeze wiki, tidy board, rehearse, **present** | — | — |

> **Final deliverables (wiki, repo, board, presentation) are not accepted late** — no grace period. Freeze everything before the posted Canvas deadline.

---

## 5. Setup Checklist (do this week)

1. Confirm a 2–3 person team; fill the availability grid; lock a weekly meeting block.
2. Create the **private** repo; add `gdparra-edu` and `cyberknowledge`.
3. Enable the Wiki; add the README with the Individual Contribution Summary Table.
4. Create the Project board (Iterative Development template) with 2-week iterations.
5. Create the four milestones **before** any issues.
6. Vote on the commit approach (recommend Individual); declare it on the proposal.
7. Load Sprint 1 with US-1 and US-2 and their tasks — each tagged with **a Milestone AND an Iteration**.
8. Commit in small, honest pieces every week — steady beats an all-nighter.
