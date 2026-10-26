window.DASHBOARD_DATA = {
  "schema": 1,
  "demo": false,
  "generated_at": "2026-10-26T21:12:26Z",
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
    "open_issues": 41,
    "open_prs": 0
  },
  "open_prs": [],
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
  "stories": [],
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
      "number": 28,
      "title": "US-1: Repository, Board & Wiki Setup",
      "url": "https://github.com/bash-y/CIS_CapstoneProj_Swag01erload/issues/28",
      "layer": null,
      "priority": "",
      "milestone": "M1: Proposal Approved",
      "assignees": [
        "UiwAntHuynhCIS"
      ]
    },
    {
      "number": 29,
      "title": "US-2: Project Proposal, Topology & Defense Test Matrix",
      "url": "https://github.com/bash-y/CIS_CapstoneProj_Swag01erload/issues/29",
      "layer": null,
      "priority": "",
      "milestone": "M1: Proposal Approved",
      "assignees": [
        "bash-y"
      ]
    },
    {
      "number": 30,
      "title": "US-3: pfSense & Dual-VLAN Virtual Network Architecture",
      "url": "https://github.com/bash-y/CIS_CapstoneProj_Swag01erload/issues/30",
      "layer": null,
      "priority": "",
      "milestone": "M2: Environment Built & Attack Demonstrated",
      "assignees": [
        "UiwAntHuynhCIS"
      ]
    },
    {
      "number": 31,
      "title": "US-4: CafÃ© Business Server & Windows Workstation Deployment",
      "url": "https://github.com/bash-y/CIS_CapstoneProj_Swag01erload/issues/31",
      "layer": null,
      "priority": "",
      "milestone": "M2: Environment Built & Attack Demonstrated",
      "assignees": [
        "bash-y"
      ]
    },
    {
      "number": 32,
      "title": "US-5: Vulnerable CafÃ© Web App & Kali Attacker Deployment",
      "url": "https://github.com/bash-y/CIS_CapstoneProj_Swag01erload/issues/32",
      "layer": null,
      "priority": "",
      "milestone": "M2: Environment Built & Attack Demonstrated",
      "assignees": [
        "joromanii"
      ]
    },
    {
      "number": 33,
      "title": "US-6: Undefended Guest-to-Business Reconnaissance & Scanning",
      "url": "https://github.com/bash-y/CIS_CapstoneProj_Swag01erload/issues/33",
      "layer": null,
      "priority": "",
      "milestone": "M2: Environment Built & Attack Demonstrated",
      "assignees": [
        "joromanii"
      ]
    },
    {
      "number": 34,
      "title": "US-7: Undefended DVWA Web Exploitation & Lateral Pivot Proof",
      "url": "https://github.com/bash-y/CIS_CapstoneProj_Swag01erload/issues/34",
      "layer": null,
      "priority": "",
      "milestone": "M2: Environment Built & Attack Demonstrated",
      "assignees": [
        "joromanii"
      ]
    },
    {
      "number": 35,
      "title": "US-8: pfSense Network Segmentation & Guest Isolation",
      "url": "https://github.com/bash-y/CIS_CapstoneProj_Swag01erload/issues/35",
      "layer": null,
      "priority": "",
      "milestone": "M3: Defenses Implemented & Verified",
      "assignees": [
        "UiwAntHuynhCIS"
      ]
    },
    {
      "number": 36,
      "title": "US-9: Windows Workstation & Server Endpoint Hardening",
      "url": "https://github.com/bash-y/CIS_CapstoneProj_Swag01erload/issues/36",
      "layer": null,
      "priority": "",
      "milestone": "M3: Defenses Implemented & Verified",
      "assignees": [
        "bash-y"
      ]
    },
    {
      "number": 37,
      "title": "US-10: Web Application Security Hardening",
      "url": "https://github.com/bash-y/CIS_CapstoneProj_Swag01erload/issues/37",
      "layer": null,
      "priority": "",
      "milestone": "M3: Defenses Implemented & Verified",
      "assignees": [
        "joromanii"
      ]
    },
    {
      "number": 38,
      "title": "US-11: Suricata IDS & Wazuh SIEM Security Monitoring",
      "url": "https://github.com/bash-y/CIS_CapstoneProj_Swag01erload/issues/38",
      "layer": null,
      "priority": "",
      "milestone": "M3: Defenses Implemented & Verified",
      "assignees": [
        "joromanii"
      ]
    },
    {
      "number": 39,
      "title": "US-12: Comprehensive Wiki Technical Report & Evidence Documentation",
      "url": "https://github.com/bash-y/CIS_CapstoneProj_Swag01erload/issues/39",
      "layer": null,
      "priority": "",
      "milestone": "M4: Documentation & Presentation",
      "assignees": [
        "UiwAntHuynhCIS"
      ]
    },
    {
      "number": 40,
      "title": "US-13: Capstone Presentation, Live Demo Flow & Rehearsal",
      "url": "https://github.com/bash-y/CIS_CapstoneProj_Swag01erload/issues/40",
      "layer": null,
      "priority": "",
      "milestone": "M4: Documentation & Presentation",
      "assignees": [
        "bash-y"
      ]
    },
    {
      "number": 42,
      "title": "US-1: Repository, Board & Wiki Setup",
      "url": "https://github.com/bash-y/CIS_CapstoneProj_Swag01erload/issues/42",
      "layer": null,
      "priority": "",
      "milestone": "M1: Proposal Approved",
      "assignees": [
        "UiwAntHuynhCIS"
      ]
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
      ]
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
      ]
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
      ]
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
      ]
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
      ]
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
      ]
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
      ]
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
      ]
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
      ]
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
      ]
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
      ]
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
      ]
    }
  ],
  "recent_failures": [],
  "activity": {
    "2026-07-29": 0,
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
    "2026-10-26": 6
  },
  "members": [
    {
      "login": "UiwAntHuynhCIS",
      "name": "Ant Huynh",
      "role": "System Architect",
      "linked": true,
      "on_roster": true,
      "commits_total": 18,
      "commits_90d": 19,
      "additions": 1963,
      "deletions": 257,
      "prs_opened": 3,
      "prs_merged": 3,
      "issues_closed": 5,
      "last_commit": "2026-10-26T20:50:13Z",
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
          "commits": 1
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
      "login": "bash-y",
      "name": "Sebastian Cadena",
      "role": "Project Lead",
      "linked": true,
      "on_roster": true,
      "commits_total": 5,
      "commits_90d": 9,
      "additions": 3008,
      "deletions": 0,
      "prs_opened": 1,
      "prs_merged": 1,
      "issues_closed": 6,
      "last_commit": "2026-10-26T20:52:29Z",
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
          "commits": 3
        }
      ]
    }
  ],
  "totals": {
    "open_prs": 0,
    "ready_prs": 0,
    "attention_prs": 0,
    "open_stories": 0,
    "open_issues": 41,
    "failures_72h": 0,
    "pct_complete": 0,
    "commits_90d": 37
  },
  "warnings": []
};
