# setup-github-milestones-and-issues.ps1
# Automates the creation of labels, milestones, and all 13 user stories for SwagPc Café.
# Requires: gh CLI authenticated with 'repo' scope.

$repo = "bash-y/CIS_CapstoneProj_Swag01erload"

Write-Host "=== Setting up GitHub Labels for $repo ===" -ForegroundColor Cyan
$labels = @(
    @{ Name = "user-story"; Color = "0E8A16"; Desc = "User Story" },
    @{ Name = "task"; Color = "1D76DB"; Desc = "Subtask" },
    @{ Name = "points:1"; Color = "D4C5F9"; Desc = "1 Story Point" },
    @{ Name = "points:2"; Color = "C5DEF5"; Desc = "2 Story Points" },
    @{ Name = "points:3"; Color = "BFD4F2"; Desc = "3 Story Points" },
    @{ Name = "points:5"; Color = "BFE5BF"; Desc = "5 Story Points" },
    @{ Name = "size:XS"; Color = "E99695"; Desc = "Task Size Extra Small" },
    @{ Name = "size:S"; Color = "F9D0C4"; Desc = "Task Size Small" },
    @{ Name = "size:M"; Color = "FEF2C0"; Desc = "Task Size Medium" },
    @{ Name = "size:L"; Color = "C2E0C6"; Desc = "Task Size Large" }
)

foreach ($l in $labels) {
    gh label create $l.Name --color $l.Color --description $l.Desc --repo $repo 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Created label: $($l.Name)" -ForegroundColor Green
    } else {
        Write-Host "Label already exists or skipped: $($l.Name)" -ForegroundColor DarkGray
    }
}

Write-Host "`n=== Creating Milestones ===" -ForegroundColor Cyan
$milestones = @(
    @{ Title = "M1: Proposal Approved"; Desc = "Repo, board, and wiki live; proposal signed off by instructor." },
    @{ Title = "M2: Environment Built & Attack Demonstrated"; Desc = "VMs/containers and virtual networks active; undefended attacks demonstrated & evidenced." },
    @{ Title = "M3: Defenses Implemented & Verified"; Desc = "Network segmentation, endpoint hardening, and monitoring configured; all verification tests pass." },
    @{ Title = "M4: Documentation & Presentation"; Desc = "Wiki report finalized; slides prepared; demo dry-run completed." }
)

foreach ($m in $milestones) {
    gh api "repos/$repo/milestones" -f title="$($m.Title)" -f description="$($m.Desc)" 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Created milestone: $($m.Title)" -ForegroundColor Green
    } else {
        Write-Host "Milestone already exists or skipped: $($m.Title)" -ForegroundColor DarkGray
    }
}

Write-Host "`n=== Creating User Story Issues ===" -ForegroundColor Cyan
$stories = @(
    @{
        Title = "US-1: Repository, Board & Wiki Setup"
        Milestone = "M1: Proposal Approved"
        Assignee = "UiwAntHuynhCIS"
        Points = "points:3"
        Body = @"
## User Story (3 pts)
**As a team**, we want a configured private repo, board, and wiki so that our project is tracked from day one.

### Subtasks
- [ ] Create private repository and add collaborators `gdparra-edu` and `cyberknowledge` (Size: XS, @UiwAntHuynhCIS)
- [ ] Enable Wiki and initialize Home page structure (Size: XS, @joromanii)
- [ ] Create GitHub Project board with Iterative Development template and 2-week iterations (Size: S, @UiwAntHuynhCIS)
- [ ] Create the four milestones (M1–M4) in the repo (Size: XS, @bash-y)
- [ ] Finalize README with team roster, roles, and contribution summary table (Size: S, @joromanii)
"@
    },
    @{
        Title = "US-2: Project Proposal, Topology & Defense Test Matrix"
        Milestone = "M1: Proposal Approved"
        Assignee = "bash-y"
        Points = "points:3"
        Body = @"
## User Story (3 pts)
**As a team**, we want an approved proposal so that we have formal instructor sign-off to proceed.

### Subtasks
- [ ] Draft scenario, brainstorm sentence, and problem statement for SwagPc Café (Size: S, @bash-y)
- [ ] Diagram initial vs. segmented network topology (WAN/pfSense/Guest/Business) (Size: M, @UiwAntHuynhCIS)
- [ ] Map course modules (Modules 2, 5, 8, 9) to specific café infrastructure (Size: S, @joromanii)
- [ ] Define test verification criteria and metrics for each defense (Size: S, @bash-y)
"@
    },
    @{
        Title = "US-3: pfSense & Dual-VLAN Virtual Network Architecture"
        Milestone = "M2: Environment Built & Attack Demonstrated"
        Assignee = "UiwAntHuynhCIS"
        Points = "points:5"
        Body = @"
## User Story (5 pts)
**As a system architect**, I want a dual-network pfSense environment so that the café guest and business networks are realistically replicated.

### Subtasks
- [ ] Deploy pfSense firewall router with WAN, Guest (VLAN 10), and Business (VLAN 20) interfaces (Size: M, @UiwAntHuynhCIS)
- [ ] Configure Docker networks / hypervisor virtual bridges (`guest-net` and `business-net`) (Size: S, @bash-y)
- [ ] Document IP addressing scheme, subnets, and routing table (Size: S, @joromanii)
- [ ] Baseline reachability test across subnets in the undefended state (Size: S, @UiwAntHuynhCIS)
"@
    },
    @{
        Title = "US-4: Café Business Server & Windows Workstation Deployment"
        Milestone = "M2: Environment Built & Attack Demonstrated"
        Assignee = "bash-y"
        Points = "points:5"
        Body = @"
## User Story (5 pts)
**As a systems administrator**, I want café business endpoints deployed so that target business resources exist.

### Subtasks
- [ ] Deploy Ubuntu Linux server VM hosting business services (Size: M, @bash-y)
- [ ] Deploy Windows employee workstation VM on the business network (Size: M, @UiwAntHuynhCIS)
- [ ] Configure employee accounts and sample business data on the workstation (Size: S, @joromanii)
- [ ] Verify employee workstation connectivity to the business server (Size: XS, @bash-y)
"@
    },
    @{
        Title = "US-5: Vulnerable Café Web App & Kali Attacker Deployment"
        Milestone = "M2: Environment Built & Attack Demonstrated"
        Assignee = "joromanii"
        Points = "points:3"
        Body = @"
## User Story (3 pts)
**As a web administrator**, I want the café web application and attacker node deployed so that the attack surface is active.

### Subtasks
- [ ] Deploy DVWA container on the Linux server representing the café web portal (Size: S, @bash-y)
- [ ] Deploy Kali Linux VM/container connected directly to the guest network (Size: S, @joromanii)
- [ ] Confirm Kali can reach the DVWA application across the undefended network (Size: XS, @joromanii)
"@
    },
    @{
        Title = "US-6: Undefended Guest-to-Business Reconnaissance & Scanning"
        Milestone = "M2: Environment Built & Attack Demonstrated"
        Assignee = "joromanii"
        Points = "points:5"
        Body = @"
## User Story (5 pts)
**As a penetration tester**, I want to conduct guest-network reconnaissance against the undefended network so that exposure is proven.

### Subtasks
- [ ] Execute ARP scan and Nmap discovery from Kali across the café network (Size: M, @joromanii)
- [ ] Enumerate open ports and services on the business server and employee workstation (Size: M, @bash-y)
- [ ] Document and capture screenshots/outputs of all exposed business assets (Size: S, @UiwAntHuynhCIS)
"@
    },
    @{
        Title = "US-7: Undefended DVWA Web Exploitation & Lateral Pivot Proof"
        Milestone = "M2: Environment Built & Attack Demonstrated"
        Assignee = "joromanii"
        Points = "points:5"
        Body = @"
## User Story (5 pts)
**As a penetration tester**, I want to exploit the café web application and demonstrate lateral movement so that business risk is proven.

### Subtasks
- [ ] Execute web exploit (command injection / SQLi) on DVWA from guest position (Size: M, @joromanii)
- [ ] Attempt lateral ping and service connection from guest position toward employee PC (Size: M, @UiwAntHuynhCIS)
- [ ] Capture all before-defense attack evidence, logs, and screenshots (Size: S, @bash-y)
"@
    },
    @{
        Title = "US-8: pfSense Network Segmentation & Guest Isolation"
        Milestone = "M3: Defenses Implemented & Verified"
        Assignee = "UiwAntHuynhCIS"
        Points = "points:5"
        Body = @"
## User Story (5 pts)
**As a network security engineer**, I want pfSense firewall segmentation so that guest traffic cannot reach business assets.

### Subtasks
- [ ] Configure pfSense firewall rules: `GUEST -> BUSINESS` DENY and LOG (Size: S, @UiwAntHuynhCIS)
- [ ] Configure rule: `GUEST -> INTERNET` ALLOW (Size: S, @UiwAntHuynhCIS)
- [ ] Configure rule: `BUSINESS -> INTERNET` and `EMPLOYEE -> SERVER` ALLOW (Size: S, @bash-y)
- [ ] **Verification Test:** Re-run Nmap and ping from Kali on Guest to Business; confirm dropped & logged (Size: M, @joromanii)
"@
    },
    @{
        Title = "US-9: Windows Workstation & Server Endpoint Hardening"
        Milestone = "M3: Defenses Implemented & Verified"
        Assignee = "bash-y"
        Points = "points:5"
        Body = @"
## User Story (5 pts)
**As an endpoint security engineer**, I want endpoint defenses configured on the business workstation so that unauthorized access is blocked.

### Subtasks
- [ ] Configure Windows Defender Firewall rules to restrict incoming connections to authorized subnets (Size: S, @bash-y)
- [ ] Disable unneeded legacy protocols (NetBIOS, LLMNR, SMBv1) on the employee PC (Size: S, @UiwAntHuynhCIS)
- [ ] Implement local account least-privilege and password policies (Size: S, @bash-y)
- [ ] **Verification Test:** Re-attempt direct connection to employee PC; confirm connection rejected (Size: M, @joromanii)
"@
    },
    @{
        Title = "US-10: Web Application Security Hardening"
        Milestone = "M3: Defenses Implemented & Verified"
        Assignee = "joromanii"
        Points = "points:2"
        Body = @"
## User Story (2 pts)
**As an application security engineer**, I want web application defenses implemented so that web exploits are mitigated.

### Subtasks
- [ ] Harden DVWA security settings (increase security level / input sanitization) (Size: S, @joromanii)
- [ ] Implement reverse proxy / web application access controls restricting web portal management (Size: S, @bash-y)
- [ ] **Verification Test:** Re-run web exploit payloads; confirm HTTP 403 or sanitized responses (Size: M, @UiwAntHuynhCIS)
"@
    },
    @{
        Title = "US-11: Suricata IDS & Wazuh SIEM Security Monitoring"
        Milestone = "M3: Defenses Implemented & Verified"
        Assignee = "joromanii"
        Points = "points:3"
        Body = @"
## User Story (3 pts)
**As a SOC analyst**, I want Suricata IDS and Wazuh SIEM deployed so that network and endpoint attacks generate alerts.

### Subtasks
- [ ] Deploy Suricata IDS monitoring traffic across the network interfaces (Size: M, @UiwAntHuynhCIS)
- [ ] Deploy Wazuh manager and configure Wazuh agents on Linux server and Windows PC (Size: M, @joromanii)
- [ ] Configure custom alert rules for reconnaissance scans and web exploitation attempts (Size: S, @bash-y)
- [ ] **Verification Test:** Re-run attack sequence; capture Wazuh dashboard alerts and log entries (Size: M, @bash-y)
"@
    },
    @{
        Title = "US-12: Comprehensive Wiki Technical Report & Evidence Documentation"
        Milestone = "M4: Documentation & Presentation"
        Assignee = "UiwAntHuynhCIS"
        Points = "points:5"
        Body = @"
## User Story (5 pts)
**As a documentation lead**, I want a comprehensive Wiki report with before-and-after evidence so that the capstone is fully documented.

### Subtasks
- [ ] Compile complete Build, Attack, and Defend sections in the GitHub Wiki (Size: M, @joromanii)
- [ ] Format before vs. after side-by-side comparison tables, screenshots, and log snippets (Size: M, @UiwAntHuynhCIS)
- [ ] Cross-check that the README contribution table matches the GitHub Project board exactly (Size: S, @bash-y)
"@
    },
    @{
        Title = "US-13: Capstone Presentation, Live Demo Flow & Rehearsal"
        Milestone = "M4: Documentation & Presentation"
        Assignee = "bash-y"
        Points = "points:5"
        Body = @"
## User Story (5 pts)
**As a team**, we want a polished presentation slide deck and rehearsed demo so that our final presentation succeeds.

### Subtasks
- [ ] Create capstone presentation slide deck covering scenario, attack, defense, and outcomes (Size: S, @bash-y)
- [ ] Script and rehearse the live/recorded demonstration video backup (Size: S, @UiwAntHuynhCIS)
- [ ] Conduct full team dry-run rehearsal (Size: S, @joromanii)
"@
    }
)

foreach ($s in $stories) {
    gh issue create --repo $repo --title "$($s.Title)" --body "$($s.Body)" --milestone "$($s.Milestone)" --assignee "$($s.Assignee)" --label "user-story,$($s.Points)" 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Created issue: $($s.Title)" -ForegroundColor Green
    } else {
        # Retry without assignee if assignee is not yet a repo collaborator
        gh issue create --repo $repo --title "$($s.Title)" --body "$($s.Body)" --milestone "$($s.Milestone)" --label "user-story,$($s.Points)" 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Created issue (unassigned): $($s.Title)" -ForegroundColor Yellow
        } else {
            Write-Host "Failed to create: $($s.Title)" -ForegroundColor Red
        }
    }
}

Write-Host "`n=== GitHub Setup Complete! ===" -ForegroundColor Green
