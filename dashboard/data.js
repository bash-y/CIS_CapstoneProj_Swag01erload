window.DASHBOARD_DATA = {
  "schema": 1,
  "demo": false,
  "generated_at": "2026-10-27T05:42:39Z",
  "repo": "bash-y/CIS_CapstoneProj_Swag01erload",
  "repo_url": "https://github.com/bash-y/CIS_CapstoneProj_Swag01erload",
  "refresh_url": "https://github.com/bash-y/CIS_CapstoneProj_Swag01erload/actions/workflows/dashboard-refresh.yml",
  "project": {
    "name": "SwagPc Café",
    "team": "Swag01erload",
    "course": "CIS 3353",
    "description": "A lab that replicates a small café network and walks Build -> Attack -> Defend: a guest-network compromise and web-app attack against an undefended build, then segmentation, firewall, endpoint and monitoring defenses, each verified by re-running the attack."
  },
  "stack_tiers": {
    "presentation": "What the user sees and touches: web pages, mobile screens, CLI output.",
    "application": "Business rules and services: APIs, controllers, background jobs.",
    "integration": "Connections to other systems: message queues, webhooks, third-party APIs.",
    "data": "Where information lives: databases, files, caches, data pipelines.",
    "security": "Identity, access control, secrets, encryption, hardening.",
    "platform": "Where the software runs: servers, containers, cloud, network.",
    "delivery": "How changes ship: build scripts, CI/CD workflows, releases.",
    "quality": "How the team knows it works: test suites, linters, scanners.",
    "observability": "How the team sees it running: logs, metrics, alerts, dashboards."
  },
  "layers": [
    {
      "id": "web-app",
      "name": "Vulnerable web application",
      "stack_tier": "application",
      "description": "The DVWA café web application the attacker reaches from the guest network; target of the controlled web attack.",
      "technologies": [
        "DVWA",
        "PHP",
        "Apache"
      ],
      "open_issues": 0,
      "closed_issues": 0,
      "open_prs": [],
      "pct": 0
    },
    {
      "id": "database",
      "name": "Application database",
      "stack_tier": "data",
      "description": "MySQL store behind the web application and the target of the SQL-injection attack.",
      "technologies": [
        "MySQL"
      ],
      "open_issues": 0,
      "closed_issues": 0,
      "open_prs": [],
      "pct": 0
    },
    {
      "id": "firewall",
      "name": "Firewall and access control",
      "stack_tier": "security",
      "description": "pfSense firewall and access-control rules enforcing Guest -> Business deny and least-privilege flows.",
      "technologies": [
        "pfSense"
      ],
      "open_issues": 0,
      "closed_issues": 0,
      "open_prs": [],
      "pct": 0
    },
    {
      "id": "endpoint",
      "name": "Endpoint hardening",
      "stack_tier": "security",
      "description": "Windows employee workstation hardening and endpoint access controls.",
      "technologies": [
        "Windows 10",
        "Group Policy"
      ],
      "open_issues": 0,
      "closed_issues": 0,
      "open_prs": [],
      "pct": 0
    },
    {
      "id": "network",
      "name": "Virtual networks and hosting",
      "stack_tier": "platform",
      "description": "Segmented virtual networks (Guest VLAN 10, Business VLAN 20) and the hypervisor / Docker host the lab runs on.",
      "technologies": [
        "VirtualBox",
        "Docker",
        "VLAN"
      ],
      "open_issues": 0,
      "closed_issues": 0,
      "open_prs": [],
      "pct": 0
    },
    {
      "id": "attack",
      "name": "Attack and verification",
      "stack_tier": "quality",
      "description": "Reconnaissance, enumeration, web-exploit and lateral-movement scripts that demonstrate the threat and re-test each defense.",
      "technologies": [
        "Kali Linux",
        "Nmap"
      ],
      "open_issues": 0,
      "closed_issues": 0,
      "open_prs": [],
      "pct": 0
    },
    {
      "id": "monitoring",
      "name": "Security monitoring",
      "stack_tier": "observability",
      "description": "Security logging, intrusion detection and SIEM alerting on reconnaissance and web attacks.",
      "technologies": [
        "Wazuh",
        "Suricata"
      ],
      "open_issues": 0,
      "closed_issues": 0,
      "open_prs": [],
      "pct": 0
    }
  ],
  "unassigned": {
    "open_issues": 44,
    "open_prs": 4
  },
  "open_prs": [
    {
      "number": 65,
      "title": "US-2 #43: fold verified segmentation results + live evidence into tes…",
      "url": "https://github.com/bash-y/CIS_CapstoneProj_Swag01erload/pull/65",
      "author": "bash-y",
      "draft": false,
      "created_at": "2026-10-27T05:17:16Z",
      "layer": null,
      "additions": 205,
      "deletions": 6,
      "checks": {
        "passed": 0,
        "failed": 0,
        "pending": 0,
        "runs": []
      },
      "review": "REVIEW_REQUIRED",
      "severity": "amber"
    },
    {
      "number": 60,
      "title": "US-4 #45: Ubuntu café business server + workstation connectivity test",
      "url": "https://github.com/bash-y/CIS_CapstoneProj_Swag01erload/pull/60",
      "author": "bash-y",
      "draft": false,
      "created_at": "2026-10-27T03:26:24Z",
      "layer": null,
      "additions": 175,
      "deletions": 0,
      "checks": {
        "passed": 0,
        "failed": 0,
        "pending": 0,
        "runs": []
      },
      "review": "REVIEW_REQUIRED",
      "severity": "amber"
    },
    {
      "number": 59,
      "title": "US-9 #50: Workstation least-privilege & password policy",
      "url": "https://github.com/bash-y/CIS_CapstoneProj_Swag01erload/pull/59",
      "author": "bash-y",
      "draft": false,
      "created_at": "2026-10-27T02:38:11Z",
      "layer": null,
      "additions": 182,
      "deletions": 0,
      "checks": {
        "passed": 0,
        "failed": 0,
        "pending": 0,
        "runs": []
      },
      "review": "REVIEW_REQUIRED",
      "severity": "amber"
    },
    {
      "number": 58,
      "title": "US-9 #50: Employee workstation inbound firewall (restrict to authorized subnets)",
      "url": "https://github.com/bash-y/CIS_CapstoneProj_Swag01erload/pull/58",
      "author": "bash-y",
      "draft": false,
      "created_at": "2026-10-27T02:34:12Z",
      "layer": null,
      "additions": 168,
      "deletions": 0,
      "checks": {
        "passed": 0,
        "failed": 0,
        "pending": 0,
        "runs": []
      },
      "review": "REVIEW_REQUIRED",
      "severity": "amber"
    }
  ],
  "milestones": [
    {
      "title": "M1: Proposal Approved",
      "description": "Repo, board, and wiki are live; proposal signed off by instructor",
      "url": "https://github.com/bash-y/CIS_CapstoneProj_Swag01erload/milestone/1",
      "state": "open",
      "due_on": null,
      "open": 5,
      "closed": 3,
      "total": 8,
      "pct": 38
    },
    {
      "title": "M2: Environment Built & Attack Demonstrated",
      "description": "VMs + virtual networks up; all attacks proven against the undefended build",
      "url": "https://github.com/bash-y/CIS_CapstoneProj_Swag01erload/milestone/2",
      "state": "open",
      "due_on": null,
      "open": 14,
      "closed": 4,
      "total": 18,
      "pct": 22
    },
    {
      "title": "M3: Defenses Implemented & Verified",
      "description": "All controls in place; every defense has a passing test",
      "url": "https://github.com/bash-y/CIS_CapstoneProj_Swag01erload/milestone/3",
      "state": "open",
      "due_on": null,
      "open": 11,
      "closed": 0,
      "total": 11,
      "pct": 0
    },
    {
      "title": "M4: Documentation & Presentation",
      "description": "Wiki report complete; demo dry-run done",
      "url": "https://github.com/bash-y/CIS_CapstoneProj_Swag01erload/milestone/4",
      "state": "open",
      "due_on": null,
      "open": 5,
      "closed": 0,
      "total": 5,
      "pct": 0
    }
  ],
  "stories": [
    {
      "number": 42,
      "title": "US-1: Repository, Board & Wiki Setup",
      "url": "https://github.com/bash-y/CIS_CapstoneProj_Swag01erload/issues/42",
      "layer": null,
      "priority": "",
      "milestone": "M1: Proposal Approved",
      "assignees": [
        "UiwAntHuynhCIS"
      ],
      "subs": [
        {
          "number": "",
          "url": "",
          "title": "Create private repository and add collaborators gdparra-edu and cyberknowledge",
          "done": false
        },
        {
          "number": "",
          "url": "",
          "title": "Enable Wiki and initialize Home page structure",
          "done": false
        },
        {
          "number": "",
          "url": "",
          "title": "Create GitHub Project board with Iterative Development template and 2-week iterations",
          "done": false
        },
        {
          "number": "",
          "url": "",
          "title": "Create the four milestones (M1â€“M4) in the repo",
          "done": false
        },
        {
          "number": "",
          "url": "",
          "title": "Finalize README with team roster, roles, and contribution summary table",
          "done": false
        }
      ],
      "sub_total": 5,
      "sub_closed": 0,
      "pct": 0
    },
    {
      "number": 43,
      "title": "US-2: Project Proposal, Topology & Defense Test Matrix",
      "url": "https://github.com/bash-y/CIS_CapstoneProj_Swag01erload/issues/43",
      "layer": null,
      "priority": "",
      "milestone": "M1: Proposal Approved",
      "assignees": [
        "bash-y"
      ],
      "subs": [
        {
          "number": "",
          "url": "",
          "title": "Draft scenario, brainstorm sentence, and problem statement for SwagPc CafÃ©",
          "done": false
        },
        {
          "number": "",
          "url": "",
          "title": "Diagram initial vs. segmented network topology (WAN/pfSense/Guest/Business)",
          "done": false
        },
        {
          "number": "",
          "url": "",
          "title": "Map course modules (Modules 2, 5, 8, 9) to specific cafÃ© infrastructure",
          "done": false
        },
        {
          "number": "",
          "url": "",
          "title": "Define test verification criteria and metrics for each defense",
          "done": false
        }
      ],
      "sub_total": 4,
      "sub_closed": 0,
      "pct": 0
    },
    {
      "number": 44,
      "title": "US-3: pfSense & Dual-VLAN Virtual Network Architecture",
      "url": "https://github.com/bash-y/CIS_CapstoneProj_Swag01erload/issues/44",
      "layer": null,
      "priority": "",
      "milestone": "M2: Environment Built & Attack Demonstrated",
      "assignees": [
        "UiwAntHuynhCIS"
      ],
      "subs": [
        {
          "number": "",
          "url": "",
          "title": "Deploy pfSense firewall router with WAN, Guest (VLAN 10), and Business (VLAN 20) interfaces",
          "done": false
        },
        {
          "number": "",
          "url": "",
          "title": "Configure Docker networks / hypervisor virtual bridges (guest-net and \business-net)",
          "done": false
        },
        {
          "number": "",
          "url": "",
          "title": "Document IP addressing scheme, subnets, and routing table",
          "done": false
        },
        {
          "number": "",
          "url": "",
          "title": "Baseline reachability test across subnets in the undefended state",
          "done": false
        }
      ],
      "sub_total": 4,
      "sub_closed": 0,
      "pct": 0
    },
    {
      "number": 45,
      "title": "US-4: CafÃ© Business Server & Windows Workstation Deployment",
      "url": "https://github.com/bash-y/CIS_CapstoneProj_Swag01erload/issues/45",
      "layer": null,
      "priority": "",
      "milestone": "M2: Environment Built & Attack Demonstrated",
      "assignees": [
        "bash-y"
      ],
      "subs": [
        {
          "number": "",
          "url": "",
          "title": "Deploy Ubuntu Linux server VM hosting business services",
          "done": false
        },
        {
          "number": "",
          "url": "",
          "title": "Deploy Windows employee workstation VM on the business network",
          "done": false
        },
        {
          "number": "",
          "url": "",
          "title": "Configure employee accounts and sample business data on the workstation",
          "done": false
        },
        {
          "number": "",
          "url": "",
          "title": "Verify employee workstation connectivity to the business server",
          "done": false
        }
      ],
      "sub_total": 4,
      "sub_closed": 0,
      "pct": 0
    },
    {
      "number": 46,
      "title": "US-5: Vulnerable CafÃ© Web App & Kali Attacker Deployment",
      "url": "https://github.com/bash-y/CIS_CapstoneProj_Swag01erload/issues/46",
      "layer": null,
      "priority": "",
      "milestone": "M2: Environment Built & Attack Demonstrated",
      "assignees": [
        "joromanii"
      ],
      "subs": [
        {
          "number": "",
          "url": "",
          "title": "Deploy DVWA container on the Linux server representing the cafÃ© web portal",
          "done": false
        },
        {
          "number": "",
          "url": "",
          "title": "Deploy Kali Linux VM/container connected directly to the guest network",
          "done": false
        },
        {
          "number": "",
          "url": "",
          "title": "Confirm Kali can reach the DVWA application across the undefended network",
          "done": false
        }
      ],
      "sub_total": 3,
      "sub_closed": 0,
      "pct": 0
    },
    {
      "number": 47,
      "title": "US-6: Undefended Guest-to-Business Reconnaissance & Scanning",
      "url": "https://github.com/bash-y/CIS_CapstoneProj_Swag01erload/issues/47",
      "layer": null,
      "priority": "",
      "milestone": "M2: Environment Built & Attack Demonstrated",
      "assignees": [
        "joromanii"
      ],
      "subs": [
        {
          "number": "",
          "url": "",
          "title": "Execute ARP scan and Nmap discovery from Kali across the cafÃ© network",
          "done": false
        },
        {
          "number": "",
          "url": "",
          "title": "Enumerate open ports and services on the business server and employee workstation",
          "done": false
        },
        {
          "number": "",
          "url": "",
          "title": "Document and capture screenshots/outputs of all exposed business assets",
          "done": false
        }
      ],
      "sub_total": 3,
      "sub_closed": 0,
      "pct": 0
    },
    {
      "number": 48,
      "title": "US-7: Undefended DVWA Web Exploitation & Lateral Pivot Proof",
      "url": "https://github.com/bash-y/CIS_CapstoneProj_Swag01erload/issues/48",
      "layer": null,
      "priority": "",
      "milestone": "M2: Environment Built & Attack Demonstrated",
      "assignees": [
        "joromanii"
      ],
      "subs": [
        {
          "number": "",
          "url": "",
          "title": "Execute web exploit (command injection / SQLi) on DVWA from guest position",
          "done": false
        },
        {
          "number": "",
          "url": "",
          "title": "Attempt lateral ping and service connection from guest position toward employee PC",
          "done": false
        },
        {
          "number": "",
          "url": "",
          "title": "Capture all before-defense attack evidence, logs, and screenshots",
          "done": false
        }
      ],
      "sub_total": 3,
      "sub_closed": 0,
      "pct": 0
    },
    {
      "number": 49,
      "title": "US-8: pfSense Network Segmentation & Guest Isolation",
      "url": "https://github.com/bash-y/CIS_CapstoneProj_Swag01erload/issues/49",
      "layer": null,
      "priority": "",
      "milestone": "M3: Defenses Implemented & Verified",
      "assignees": [
        "UiwAntHuynhCIS"
      ],
      "subs": [
        {
          "number": "",
          "url": "",
          "title": "Configure pfSense firewall rules: GUEST -> BUSINESS DENY and LOG",
          "done": false
        },
        {
          "number": "",
          "url": "",
          "title": "Configure rule: GUEST -> INTERNET ALLOW",
          "done": false
        },
        {
          "number": "",
          "url": "",
          "title": "Configure rule: BUSINESS -> INTERNET and EMPLOYEE -> SERVER ALLOW",
          "done": false
        },
        {
          "number": "",
          "url": "",
          "title": "**Verification Test:** Re-run Nmap and ping from Kali on Guest to Business; confirm dropped & logged",
          "done": false
        }
      ],
      "sub_total": 4,
      "sub_closed": 0,
      "pct": 0
    },
    {
      "number": 50,
      "title": "US-9: Windows Workstation & Server Endpoint Hardening",
      "url": "https://github.com/bash-y/CIS_CapstoneProj_Swag01erload/issues/50",
      "layer": null,
      "priority": "",
      "milestone": "M3: Defenses Implemented & Verified",
      "assignees": [
        "bash-y"
      ],
      "subs": [
        {
          "number": "",
          "url": "",
          "title": "Configure Windows Defender Firewall rules to restrict incoming connections to authorized subnets",
          "done": false
        },
        {
          "number": "",
          "url": "",
          "title": "Disable unneeded legacy protocols (NetBIOS, LLMNR, SMBv1) on the employee PC",
          "done": false
        },
        {
          "number": "",
          "url": "",
          "title": "Implement local account least-privilege and password policies",
          "done": false
        },
        {
          "number": "",
          "url": "",
          "title": "**Verification Test:** Re-attempt direct connection to employee PC; confirm connection rejected",
          "done": false
        }
      ],
      "sub_total": 4,
      "sub_closed": 0,
      "pct": 0
    },
    {
      "number": 51,
      "title": "US-10: Web Application Security Hardening",
      "url": "https://github.com/bash-y/CIS_CapstoneProj_Swag01erload/issues/51",
      "layer": null,
      "priority": "",
      "milestone": "M3: Defenses Implemented & Verified",
      "assignees": [
        "joromanii"
      ],
      "subs": [
        {
          "number": "",
          "url": "",
          "title": "Harden DVWA security settings (increase security level / input sanitization)",
          "done": false
        },
        {
          "number": "",
          "url": "",
          "title": "Implement reverse proxy / web application access controls restricting web portal management",
          "done": false
        },
        {
          "number": "",
          "url": "",
          "title": "**Verification Test:** Re-run web exploit payloads; confirm HTTP 403 or sanitized responses",
          "done": false
        }
      ],
      "sub_total": 3,
      "sub_closed": 0,
      "pct": 0
    },
    {
      "number": 52,
      "title": "US-11: Suricata IDS & Wazuh SIEM Security Monitoring",
      "url": "https://github.com/bash-y/CIS_CapstoneProj_Swag01erload/issues/52",
      "layer": null,
      "priority": "",
      "milestone": "M3: Defenses Implemented & Verified",
      "assignees": [
        "joromanii"
      ],
      "subs": [
        {
          "number": "",
          "url": "",
          "title": "Deploy Suricata IDS monitoring traffic across the network interfaces",
          "done": false
        },
        {
          "number": "",
          "url": "",
          "title": "Deploy Wazuh manager and configure Wazuh agents on Linux server and Windows PC",
          "done": false
        },
        {
          "number": "",
          "url": "",
          "title": "Configure custom alert rules for reconnaissance scans and web exploitation attempts",
          "done": false
        },
        {
          "number": "",
          "url": "",
          "title": "**Verification Test:** Re-run attack sequence; capture Wazuh dashboard alerts and log entries",
          "done": false
        }
      ],
      "sub_total": 4,
      "sub_closed": 0,
      "pct": 0
    },
    {
      "number": 53,
      "title": "US-12: Comprehensive Wiki Technical Report & Evidence Documentation",
      "url": "https://github.com/bash-y/CIS_CapstoneProj_Swag01erload/issues/53",
      "layer": null,
      "priority": "",
      "milestone": "M4: Documentation & Presentation",
      "assignees": [
        "UiwAntHuynhCIS"
      ],
      "subs": [
        {
          "number": "",
          "url": "",
          "title": "Compile complete Build, Attack, and Defend sections in the GitHub Wiki",
          "done": false
        },
        {
          "number": "",
          "url": "",
          "title": "Format before vs. after side-by-side comparison tables, screenshots, and log snippets",
          "done": false
        },
        {
          "number": "",
          "url": "",
          "title": "Cross-check that the README contribution table matches the GitHub Project board exactly",
          "done": false
        }
      ],
      "sub_total": 3,
      "sub_closed": 0,
      "pct": 0
    },
    {
      "number": 54,
      "title": "US-13: Capstone Presentation, Live Demo Flow & Rehearsal",
      "url": "https://github.com/bash-y/CIS_CapstoneProj_Swag01erload/issues/54",
      "layer": null,
      "priority": "",
      "milestone": "M4: Documentation & Presentation",
      "assignees": [
        "bash-y"
      ],
      "subs": [
        {
          "number": "",
          "url": "",
          "title": "Create capstone presentation slide deck covering scenario, attack, defense, and outcomes",
          "done": false
        },
        {
          "number": "",
          "url": "",
          "title": "Script and rehearse the live/recorded demonstration video backup",
          "done": false
        },
        {
          "number": "",
          "url": "",
          "title": "Conduct full team dry-run rehearsal",
          "done": false
        }
      ],
      "sub_total": 3,
      "sub_closed": 0,
      "pct": 0
    }
  ],
  "open_issues": [
    {
      "number": 2,
      "title": "Create possible Attack",
      "url": "https://github.com/bash-y/CIS_CapstoneProj_Swag01erload/issues/2",
      "layer": null,
      "priority": "",
      "milestone": "M2: Environment Built & Attack Demonstrated",
      "assignees": []
    },
    {
      "number": 3,
      "title": "Test Attack",
      "url": "https://github.com/bash-y/CIS_CapstoneProj_Swag01erload/issues/3",
      "layer": null,
      "priority": "",
      "milestone": "M2: Environment Built & Attack Demonstrated",
      "assignees": []
    },
    {
      "number": 4,
      "title": "Document Base Attack",
      "url": "https://github.com/bash-y/CIS_CapstoneProj_Swag01erload/issues/4",
      "layer": null,
      "priority": "",
      "milestone": "M2: Environment Built & Attack Demonstrated",
      "assignees": []
    },
    {
      "number": 6,
      "title": "Demonstrate undefended SQL injection",
      "url": "https://github.com/bash-y/CIS_CapstoneProj_Swag01erload/issues/6",
      "layer": null,
      "priority": "",
      "milestone": "M2: Environment Built & Attack Demonstrated",
      "assignees": []
    },
    {
      "number": 7,
      "title": "WAF (ModSecurity+CRS) + verification",
      "url": "https://github.com/bash-y/CIS_CapstoneProj_Swag01erload/issues/7",
      "layer": null,
      "priority": "",
      "milestone": "M3: Defenses Implemented & Verified",
      "assignees": []
    },
    {
      "number": 8,
      "title": "Network segmentation + verification",
      "url": "https://github.com/bash-y/CIS_CapstoneProj_Swag01erload/issues/8",
      "layer": null,
      "priority": "",
      "milestone": "M3: Defenses Implemented & Verified",
      "assignees": []
    },
    {
      "number": 9,
      "title": "Monitoring & logging + verification",
      "url": "https://github.com/bash-y/CIS_CapstoneProj_Swag01erload/issues/9",
      "layer": null,
      "priority": "",
      "milestone": "M3: Defenses Implemented & Verified",
      "assignees": []
    },
    {
      "number": 10,
      "title": "Wiki final report & presentation",
      "url": "https://github.com/bash-y/CIS_CapstoneProj_Swag01erload/issues/10",
      "layer": null,
      "priority": "",
      "milestone": "M4: Documentation & Presentation",
      "assignees": []
    },
    {
      "number": 17,
      "title": "Research and Create Documentation",
      "url": "https://github.com/bash-y/CIS_CapstoneProj_Swag01erload/issues/17",
      "layer": null,
      "priority": "",
      "milestone": "M1: Proposal Approved",
      "assignees": [
        "joromanii"
      ]
    },
    {
      "number": 21,
      "title": "Create Firewall Rules",
      "url": "https://github.com/bash-y/CIS_CapstoneProj_Swag01erload/issues/21",
      "layer": null,
      "priority": "",
      "milestone": "",
      "assignees": [
        "joromanii"
      ]
    },
    {
      "number": 22,
      "title": "Document Firewall Rules",
      "url": "https://github.com/bash-y/CIS_CapstoneProj_Swag01erload/issues/22",
      "layer": null,
      "priority": "",
      "milestone": "",
      "assignees": []
    },
    {
      "number": 23,
      "title": "Add Web Application Firewall ( WAF)",
      "url": "https://github.com/bash-y/CIS_CapstoneProj_Swag01erload/issues/23",
      "layer": null,
      "priority": "",
      "milestone": "",
      "assignees": []
    },
    {
      "number": 24,
      "title": "Verify WAF capabilties",
      "url": "https://github.com/bash-y/CIS_CapstoneProj_Swag01erload/issues/24",
      "layer": null,
      "priority": "",
      "milestone": "",
      "assignees": []
    },
    {
      "number": 25,
      "title": "Document WAF",
      "url": "https://github.com/bash-y/CIS_CapstoneProj_Swag01erload/issues/25",
      "layer": null,
      "priority": "",
      "milestone": "",
      "assignees": []
    },
    {
      "number": 26,
      "title": "Create Bash Script for firewall rules set up",
      "url": "https://github.com/bash-y/CIS_CapstoneProj_Swag01erload/issues/26",
      "layer": null,
      "priority": "",
      "milestone": "",
      "assignees": []
    },
    {
      "number": 62,
      "title": "Suricata service fails to start: hostname + network_mode conflict (US-11)",
      "url": "https://github.com/bash-y/CIS_CapstoneProj_Swag01erload/issues/62",
      "layer": null,
      "priority": "",
      "milestone": "",
      "assignees": [
        "joromanii"
      ]
    },
    {
      "number": 63,
      "title": "run-full-attack.sh command-injection step returns no output (US-7)",
      "url": "https://github.com/bash-y/CIS_CapstoneProj_Swag01erload/issues/63",
      "layer": null,
      "priority": "",
      "milestone": "",
      "assignees": [
        "joromanii"
      ]
    },
    {
      "number": 64,
      "title": "verify-defenses.sh Test 2 false-negative: curl -s hides blocked timeout (US-8)",
      "url": "https://github.com/bash-y/CIS_CapstoneProj_Swag01erload/issues/64",
      "layer": null,
      "priority": "",
      "milestone": "",
      "assignees": [
        "UiwAntHuynhCIS"
      ]
    }
  ],
  "recent_failures": [],
  "activity": {
    "2026-07-30": 0,
    "2026-07-31": 0,
    "2026-08-01": 0,
    "2026-08-02": 0,
    "2026-08-03": 0,
    "2026-08-04": 0,
    "2026-08-05": 0,
    "2026-08-06": 0,
    "2026-08-07": 0,
    "2026-08-08": 0,
    "2026-08-09": 0,
    "2026-08-10": 0,
    "2026-08-11": 0,
    "2026-08-12": 0,
    "2026-08-13": 0,
    "2026-08-14": 0,
    "2026-08-15": 0,
    "2026-08-16": 0,
    "2026-08-17": 0,
    "2026-08-18": 0,
    "2026-08-19": 0,
    "2026-08-20": 0,
    "2026-08-21": 0,
    "2026-08-22": 0,
    "2026-08-23": 0,
    "2026-08-24": 0,
    "2026-08-25": 0,
    "2026-08-26": 0,
    "2026-08-27": 0,
    "2026-08-28": 0,
    "2026-08-29": 0,
    "2026-08-30": 0,
    "2026-08-31": 3,
    "2026-09-01": 0,
    "2026-09-02": 1,
    "2026-09-03": 0,
    "2026-09-04": 0,
    "2026-09-05": 0,
    "2026-09-06": 0,
    "2026-09-07": 0,
    "2026-09-08": 0,
    "2026-09-09": 0,
    "2026-09-10": 0,
    "2026-09-11": 0,
    "2026-09-12": 0,
    "2026-09-13": 0,
    "2026-09-14": 1,
    "2026-09-15": 0,
    "2026-09-16": 0,
    "2026-09-17": 0,
    "2026-09-18": 0,
    "2026-09-19": 0,
    "2026-09-20": 0,
    "2026-09-21": 0,
    "2026-09-22": 0,
    "2026-09-23": 0,
    "2026-09-24": 0,
    "2026-09-25": 0,
    "2026-09-26": 0,
    "2026-09-27": 0,
    "2026-09-28": 2,
    "2026-09-29": 0,
    "2026-09-30": 6,
    "2026-10-01": 0,
    "2026-10-02": 0,
    "2026-10-03": 0,
    "2026-10-04": 0,
    "2026-10-05": 0,
    "2026-10-06": 0,
    "2026-10-07": 0,
    "2026-10-08": 0,
    "2026-10-09": 0,
    "2026-10-10": 0,
    "2026-10-11": 0,
    "2026-10-12": 4,
    "2026-10-13": 0,
    "2026-10-14": 7,
    "2026-10-15": 0,
    "2026-10-16": 0,
    "2026-10-17": 0,
    "2026-10-18": 1,
    "2026-10-19": 2,
    "2026-10-20": 0,
    "2026-10-21": 8,
    "2026-10-22": 7,
    "2026-10-23": 2,
    "2026-10-24": 0,
    "2026-10-25": 0,
    "2026-10-26": 10,
    "2026-10-27": 9
  },
  "members": [
    {
      "login": "UiwAntHuynhCIS",
      "name": "Ant Huynh",
      "role": "System Architect",
      "linked": true,
      "on_roster": true,
      "commits_total": 18,
      "commits_90d": 23,
      "additions": 1963,
      "deletions": 257,
      "prs_opened": 3,
      "prs_merged": 3,
      "issues_closed": 5,
      "last_commit": "2026-10-27T05:29:44Z",
      "weekly": [
        {
          "week": "2026-08-10",
          "commits": 0
        },
        {
          "week": "2026-08-17",
          "commits": 0
        },
        {
          "week": "2026-08-24",
          "commits": 0
        },
        {
          "week": "2026-08-31",
          "commits": 0
        },
        {
          "week": "2026-09-07",
          "commits": 0
        },
        {
          "week": "2026-09-14",
          "commits": 1
        },
        {
          "week": "2026-09-21",
          "commits": 0
        },
        {
          "week": "2026-09-28",
          "commits": 1
        },
        {
          "week": "2026-10-05",
          "commits": 0
        },
        {
          "week": "2026-10-12",
          "commits": 5
        },
        {
          "week": "2026-10-19",
          "commits": 11
        },
        {
          "week": "2026-10-26",
          "commits": 5
        }
      ]
    },
    {
      "login": "bash-y",
      "name": "Sebastian Cadena",
      "role": "Project Lead",
      "linked": true,
      "on_roster": true,
      "commits_total": 10,
      "commits_90d": 14,
      "additions": 4971,
      "deletions": 544,
      "prs_opened": 9,
      "prs_merged": 5,
      "issues_closed": 6,
      "last_commit": "2026-10-27T05:06:11Z",
      "weekly": [
        {
          "week": "2026-08-10",
          "commits": 0
        },
        {
          "week": "2026-08-17",
          "commits": 0
        },
        {
          "week": "2026-08-24",
          "commits": 0
        },
        {
          "week": "2026-08-31",
          "commits": 4
        },
        {
          "week": "2026-09-07",
          "commits": 0
        },
        {
          "week": "2026-09-14",
          "commits": 0
        },
        {
          "week": "2026-09-21",
          "commits": 0
        },
        {
          "week": "2026-09-28",
          "commits": 0
        },
        {
          "week": "2026-10-05",
          "commits": 0
        },
        {
          "week": "2026-10-12",
          "commits": 2
        },
        {
          "week": "2026-10-19",
          "commits": 0
        },
        {
          "week": "2026-10-26",
          "commits": 8
        }
      ]
    },
    {
      "login": "joromanii",
      "name": "Jo Romani",
      "role": "Security-Documentation Lead",
      "linked": true,
      "on_roster": true,
      "commits_total": 9,
      "commits_90d": 9,
      "additions": 961,
      "deletions": 1,
      "prs_opened": 0,
      "prs_merged": 0,
      "issues_closed": 2,
      "last_commit": "2026-10-21T21:49:11Z",
      "weekly": [
        {
          "week": "2026-08-10",
          "commits": 0
        },
        {
          "week": "2026-08-17",
          "commits": 0
        },
        {
          "week": "2026-08-24",
          "commits": 0
        },
        {
          "week": "2026-08-31",
          "commits": 0
        },
        {
          "week": "2026-09-07",
          "commits": 0
        },
        {
          "week": "2026-09-14",
          "commits": 0
        },
        {
          "week": "2026-09-21",
          "commits": 0
        },
        {
          "week": "2026-09-28",
          "commits": 1
        },
        {
          "week": "2026-10-05",
          "commits": 0
        },
        {
          "week": "2026-10-12",
          "commits": 0
        },
        {
          "week": "2026-10-19",
          "commits": 8
        },
        {
          "week": "2026-10-26",
          "commits": 0
        }
      ]
    },
    {
      "login": "claude",
      "name": "claude",
      "role": "",
      "linked": true,
      "on_roster": false,
      "commits_total": 5,
      "commits_90d": 0,
      "additions": 1963,
      "deletions": 544,
      "prs_opened": 0,
      "prs_merged": 0,
      "issues_closed": 0,
      "last_commit": null,
      "weekly": [
        {
          "week": "2026-08-10",
          "commits": 0
        },
        {
          "week": "2026-08-17",
          "commits": 0
        },
        {
          "week": "2026-08-24",
          "commits": 0
        },
        {
          "week": "2026-08-31",
          "commits": 0
        },
        {
          "week": "2026-09-07",
          "commits": 0
        },
        {
          "week": "2026-09-14",
          "commits": 0
        },
        {
          "week": "2026-09-21",
          "commits": 0
        },
        {
          "week": "2026-09-28",
          "commits": 0
        },
        {
          "week": "2026-10-05",
          "commits": 0
        },
        {
          "week": "2026-10-12",
          "commits": 0
        },
        {
          "week": "2026-10-19",
          "commits": 0
        },
        {
          "week": "2026-10-26",
          "commits": 0
        }
      ]
    }
  ],
  "totals": {
    "open_prs": 4,
    "ready_prs": 0,
    "attention_prs": 0,
    "open_stories": 13,
    "open_issues": 31,
    "failures_72h": 0,
    "pct_complete": 17,
    "issues_closed": 9,
    "issues_total": 53,
    "story_tasks": 47,
    "story_tasks_done": 0,
    "story_pct": 0,
    "commits_90d": 46
  },
  "warnings": []
};
