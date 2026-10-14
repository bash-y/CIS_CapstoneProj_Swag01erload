window.DASHBOARD_DATA = {
  "schema": 1,
  "demo": true,
  "generated_at": "2026-10-07T20:53:50Z",
  "repo": "your-org/your-repo",
  "repo_url": "https://github.com/your-org/your-repo",
  "refresh_url": "https://github.com/your-org/your-repo/actions/workflows/dashboard-refresh.yml",
  "project": {
    "name": "Example Project",
    "team": "Team Name",
    "course": "COURSE 0000",
    "description": "One sentence that says what your software does and who it is for."
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
      "id": "web-ui",
      "name": "Web interface",
      "stack_tier": "presentation",
      "description": "Pages and forms the user sees in the browser.",
      "technologies": [
        "HTML",
        "CSS",
        "JavaScript"
      ],
      "open_issues": 1,
      "closed_issues": 2,
      "open_prs": [
        {
          "number": 41,
          "title": "Add sign-in form and session handling",
          "url": "https://github.com/your-org/your-repo/pull/41",
          "severity": "green"
        }
      ],
      "pct": 67
    },
    {
      "id": "api",
      "name": "REST API",
      "stack_tier": "application",
      "description": "Endpoints that receive requests from the interface and apply the business rules.",
      "technologies": [
        "Python",
        "Flask"
      ],
      "open_issues": 1,
      "closed_issues": 3,
      "open_prs": [
        {
          "number": 44,
          "title": "Return 404 for unknown record IDs",
          "url": "https://github.com/your-org/your-repo/pull/44",
          "severity": "amber"
        }
      ],
      "pct": 75
    },
    {
      "id": "database",
      "name": "Database",
      "stack_tier": "data",
      "description": "Tables that store users, records and audit events.",
      "technologies": [
        "PostgreSQL"
      ],
      "open_issues": 3,
      "closed_issues": 2,
      "open_prs": [
        {
          "number": 43,
          "title": "Create records table and seed script",
          "url": "https://github.com/your-org/your-repo/pull/43",
          "severity": "red"
        }
      ],
      "pct": 40
    },
    {
      "id": "auth",
      "name": "Login and access control",
      "stack_tier": "security",
      "description": "Who can sign in and what each role is allowed to do.",
      "technologies": [
        "OAuth 2.0",
        "bcrypt"
      ],
      "open_issues": 0,
      "closed_issues": 3,
      "open_prs": [],
      "pct": 100
    },
    {
      "id": "infra",
      "name": "Containers and hosting",
      "stack_tier": "platform",
      "description": "Where the software runs and how its parts are connected.",
      "technologies": [
        "Docker",
        "Docker Compose"
      ],
      "open_issues": 2,
      "closed_issues": 2,
      "open_prs": [],
      "pct": 50
    },
    {
      "id": "ci",
      "name": "Build and test pipeline",
      "stack_tier": "delivery",
      "description": "GitHub Actions workflows that build, test and publish the project.",
      "technologies": [
        "GitHub Actions"
      ],
      "open_issues": 2,
      "closed_issues": 3,
      "open_prs": [],
      "pct": 60
    }
  ],
  "unassigned": {
    "open_issues": 1,
    "open_prs": 1
  },
  "open_prs": [
    {
      "number": 41,
      "title": "Add sign-in form and session handling",
      "url": "https://github.com/your-org/your-repo/pull/41",
      "author": "student-a",
      "draft": false,
      "created_at": "2026-10-07T20:53:50Z",
      "layer": "web-ui",
      "additions": 120,
      "deletions": 14,
      "checks": {
        "passed": 3,
        "failed": 0,
        "pending": 0,
        "runs": [
          {
            "name": "dashboard-checks",
            "state": "passed"
          },
          {
            "name": "layer-tests",
            "state": "passed"
          },
          {
            "name": "all-green",
            "state": "passed"
          }
        ]
      },
      "review": "APPROVED",
      "severity": "green"
    },
    {
      "number": 43,
      "title": "Create records table and seed script",
      "url": "https://github.com/your-org/your-repo/pull/43",
      "author": "student-a",
      "draft": false,
      "created_at": "2026-10-07T20:53:50Z",
      "layer": "database",
      "additions": 120,
      "deletions": 14,
      "checks": {
        "passed": 1,
        "failed": 1,
        "pending": 0,
        "runs": [
          {
            "name": "dashboard-checks",
            "state": "passed"
          },
          {
            "name": "layer-tests",
            "state": "failed"
          }
        ]
      },
      "review": "CHANGES_REQUESTED",
      "severity": "red"
    },
    {
      "number": 44,
      "title": "Return 404 for unknown record IDs",
      "url": "https://github.com/your-org/your-repo/pull/44",
      "author": "student-a",
      "draft": false,
      "created_at": "2026-10-07T20:53:50Z",
      "layer": "api",
      "additions": 120,
      "deletions": 14,
      "checks": {
        "passed": 1,
        "failed": 0,
        "pending": 1,
        "runs": [
          {
            "name": "dashboard-checks",
            "state": "passed"
          },
          {
            "name": "layer-tests",
            "state": "pending"
          }
        ]
      },
      "review": "REVIEW_REQUIRED",
      "severity": "amber"
    },
    {
      "number": 45,
      "title": "Draft: container health checks",
      "url": "https://github.com/your-org/your-repo/pull/45",
      "author": "student-a",
      "draft": true,
      "created_at": "2026-10-07T20:53:50Z",
      "layer": null,
      "additions": 120,
      "deletions": 14,
      "checks": {
        "passed": 1,
        "failed": 0,
        "pending": 1,
        "runs": [
          {
            "name": "dashboard-checks",
            "state": "passed"
          },
          {
            "name": "layer-tests",
            "state": "pending"
          }
        ]
      },
      "review": "REVIEW_REQUIRED",
      "severity": "amber"
    }
  ],
  "milestones": [
    {
      "title": "Sprint 1: Walking skeleton",
      "description": "Every layer exists and talks to the next one.",
      "url": "https://github.com/your-org/your-repo/milestone/1",
      "state": "closed",
      "due_on": null,
      "open": 0,
      "closed": 8,
      "total": 8,
      "pct": 100
    },
    {
      "title": "Sprint 2: Core features",
      "description": "The three user stories the project is graded on.",
      "url": "https://github.com/your-org/your-repo/milestone/2",
      "state": "open",
      "due_on": null,
      "open": 5,
      "closed": 7,
      "total": 12,
      "pct": 58
    },
    {
      "title": "Sprint 3: Hardening and demo",
      "description": "Security review, tests and the final demo.",
      "url": "https://github.com/your-org/your-repo/milestone/3",
      "state": "open",
      "due_on": null,
      "open": 9,
      "closed": 1,
      "total": 10,
      "pct": 10
    }
  ],
  "stories": [
    {
      "number": 30,
      "title": "As a user I can sign in and see only my own records",
      "url": "https://github.com/your-org/your-repo/issues/30",
      "layer": "auth",
      "priority": "P1",
      "milestone": "Sprint 2: Core features",
      "assignees": [
        "student-a"
      ],
      "subs": [
        {
          "number": 31,
          "title": "Login form",
          "url": "https://github.com/your-org/your-repo/issues/31",
          "done": true
        },
        {
          "number": 32,
          "title": "Password hashing",
          "url": "https://github.com/your-org/your-repo/issues/32",
          "done": true
        },
        {
          "number": 33,
          "title": "Role check on every endpoint",
          "url": "https://github.com/your-org/your-repo/issues/33",
          "done": false
        }
      ],
      "sub_total": 3,
      "sub_closed": 2,
      "pct": 67
    },
    {
      "number": 34,
      "title": "As a user I can search records by keyword",
      "url": "https://github.com/your-org/your-repo/issues/34",
      "layer": "api",
      "priority": "P2",
      "milestone": "Sprint 2: Core features",
      "assignees": [
        "student-b"
      ],
      "subs": [
        {
          "number": 35,
          "title": "Search endpoint",
          "url": "https://github.com/your-org/your-repo/issues/35",
          "done": true
        },
        {
          "number": 36,
          "title": "Search box on the page",
          "url": "https://github.com/your-org/your-repo/issues/36",
          "done": false
        }
      ],
      "sub_total": 2,
      "sub_closed": 1,
      "pct": 50
    },
    {
      "number": 37,
      "title": "As the team we can deploy with one command",
      "url": "https://github.com/your-org/your-repo/issues/37",
      "layer": "infra",
      "priority": "P2",
      "milestone": "Sprint 3: Hardening and demo",
      "assignees": [],
      "subs": [],
      "sub_total": 0,
      "sub_closed": 0,
      "pct": 0
    }
  ],
  "open_issues": [
    {
      "number": 38,
      "title": "Error page shows a stack trace",
      "url": "https://github.com/your-org/your-repo/issues/38",
      "layer": "api",
      "priority": "P1",
      "milestone": "Sprint 3: Hardening and demo",
      "assignees": [
        "student-c"
      ]
    },
    {
      "number": 39,
      "title": "Write the README setup steps",
      "url": "https://github.com/your-org/your-repo/issues/39",
      "layer": null,
      "priority": "",
      "milestone": "",
      "assignees": []
    }
  ],
  "recent_failures": [
    {
      "workflow": "Build tests",
      "branch": "feature/records-table",
      "event": "pull_request",
      "url": "https://github.com/your-org/your-repo/actions",
      "created_at": "2026-10-07T20:53:50Z",
      "prs": [
        43
      ]
    }
  ],
  "activity": {
    "2026-07-10": 0,
    "2026-07-11": 0,
    "2026-07-12": 0,
    "2026-07-13": 0,
    "2026-07-14": 0,
    "2026-07-15": 0,
    "2026-07-16": 0,
    "2026-07-17": 0,
    "2026-07-18": 0,
    "2026-07-19": 0,
    "2026-07-20": 0,
    "2026-07-21": 0,
    "2026-07-22": 0,
    "2026-07-23": 0,
    "2026-07-24": 0,
    "2026-07-25": 0,
    "2026-07-26": 0,
    "2026-07-27": 0,
    "2026-07-28": 0,
    "2026-07-29": 0,
    "2026-07-30": 0,
    "2026-07-31": 1,
    "2026-08-01": 8,
    "2026-08-02": 6,
    "2026-08-03": 5,
    "2026-08-04": 3,
    "2026-08-05": 0,
    "2026-08-06": 1,
    "2026-08-07": 7,
    "2026-08-08": 5,
    "2026-08-09": 4,
    "2026-08-10": 2,
    "2026-08-11": 0,
    "2026-08-12": 1,
    "2026-08-13": 0,
    "2026-08-14": 4,
    "2026-08-15": 3,
    "2026-08-16": 1,
    "2026-08-17": 8,
    "2026-08-18": 7,
    "2026-08-19": 0,
    "2026-08-20": 1,
    "2026-08-21": 2,
    "2026-08-22": 0,
    "2026-08-23": 7,
    "2026-08-24": 6,
    "2026-08-25": 4,
    "2026-08-26": 1,
    "2026-08-27": 0,
    "2026-08-28": 8,
    "2026-08-29": 6,
    "2026-08-30": 5,
    "2026-08-31": 3,
    "2026-09-01": 1,
    "2026-09-02": 0,
    "2026-09-03": 1,
    "2026-09-04": 5,
    "2026-09-05": 4,
    "2026-09-06": 2,
    "2026-09-07": 0,
    "2026-09-08": 8,
    "2026-09-09": 1,
    "2026-09-10": 0,
    "2026-09-11": 3,
    "2026-09-12": 1,
    "2026-09-13": 8,
    "2026-09-14": 7,
    "2026-09-15": 5,
    "2026-09-16": 0,
    "2026-09-17": 1,
    "2026-09-18": 0,
    "2026-09-19": 7,
    "2026-09-20": 6,
    "2026-09-21": 4,
    "2026-09-22": 2,
    "2026-09-23": 1,
    "2026-09-24": 0,
    "2026-09-25": 6,
    "2026-09-26": 5,
    "2026-09-27": 3,
    "2026-09-28": 1,
    "2026-09-29": 0,
    "2026-09-30": 0,
    "2026-10-01": 1,
    "2026-10-02": 4,
    "2026-10-03": 2,
    "2026-10-04": 0,
    "2026-10-05": 8,
    "2026-10-06": 6,
    "2026-10-07": 1
  },
  "members": [
    {
      "login": "student-a",
      "name": "Student A",
      "role": "Frontend",
      "linked": true,
      "on_roster": true,
      "commits_total": 42,
      "commits_90d": 29,
      "additions": 1810,
      "deletions": 420,
      "prs_opened": 5,
      "prs_merged": 4,
      "issues_closed": 7,
      "last_commit": "2026-10-07T20:53:50Z",
      "weekly": [
        {
          "week": "2026-07-20",
          "commits": 0
        },
        {
          "week": "2026-07-27",
          "commits": 3
        },
        {
          "week": "2026-08-03",
          "commits": 1
        },
        {
          "week": "2026-08-10",
          "commits": 4
        },
        {
          "week": "2026-08-17",
          "commits": 2
        },
        {
          "week": "2026-08-24",
          "commits": 0
        },
        {
          "week": "2026-08-31",
          "commits": 3
        },
        {
          "week": "2026-09-07",
          "commits": 1
        },
        {
          "week": "2026-09-14",
          "commits": 4
        },
        {
          "week": "2026-09-21",
          "commits": 2
        },
        {
          "week": "2026-09-28",
          "commits": 0
        },
        {
          "week": "2026-10-05",
          "commits": 9
        }
      ]
    },
    {
      "login": "student-b",
      "name": "Student B",
      "role": "Backend",
      "linked": true,
      "on_roster": true,
      "commits_total": 35,
      "commits_90d": 24,
      "additions": 2210,
      "deletions": 690,
      "prs_opened": 4,
      "prs_merged": 3,
      "issues_closed": 5,
      "last_commit": "2026-10-07T20:53:50Z",
      "weekly": [
        {
          "week": "2026-07-20",
          "commits": 0
        },
        {
          "week": "2026-07-27",
          "commits": 3
        },
        {
          "week": "2026-08-03",
          "commits": 2
        },
        {
          "week": "2026-08-10",
          "commits": 2
        },
        {
          "week": "2026-08-17",
          "commits": 1
        },
        {
          "week": "2026-08-24",
          "commits": 0
        },
        {
          "week": "2026-08-31",
          "commits": 3
        },
        {
          "week": "2026-09-07",
          "commits": 2
        },
        {
          "week": "2026-09-14",
          "commits": 2
        },
        {
          "week": "2026-09-21",
          "commits": 1
        },
        {
          "week": "2026-09-28",
          "commits": 0
        },
        {
          "week": "2026-10-05",
          "commits": 8
        }
      ]
    },
    {
      "login": "student-c",
      "name": "Student C",
      "role": "Data and security",
      "linked": true,
      "on_roster": true,
      "commits_total": 19,
      "commits_90d": 13,
      "additions": 640,
      "deletions": 110,
      "prs_opened": 2,
      "prs_merged": 1,
      "issues_closed": 3,
      "last_commit": "2026-10-07T20:53:50Z",
      "weekly": [
        {
          "week": "2026-07-20",
          "commits": 1
        },
        {
          "week": "2026-07-27",
          "commits": 1
        },
        {
          "week": "2026-08-03",
          "commits": 1
        },
        {
          "week": "2026-08-10",
          "commits": 1
        },
        {
          "week": "2026-08-17",
          "commits": 1
        },
        {
          "week": "2026-08-24",
          "commits": 1
        },
        {
          "week": "2026-08-31",
          "commits": 1
        },
        {
          "week": "2026-09-07",
          "commits": 1
        },
        {
          "week": "2026-09-14",
          "commits": 1
        },
        {
          "week": "2026-09-21",
          "commits": 1
        },
        {
          "week": "2026-09-28",
          "commits": 1
        },
        {
          "week": "2026-10-05",
          "commits": 2
        }
      ]
    },
    {
      "login": "student-d",
      "name": "Student D",
      "role": "DevOps",
      "linked": true,
      "on_roster": true,
      "commits_total": 0,
      "commits_90d": 0,
      "additions": 0,
      "deletions": 0,
      "prs_opened": 0,
      "prs_merged": 0,
      "issues_closed": 0,
      "last_commit": null,
      "weekly": [
        {
          "week": "2026-07-20",
          "commits": 0
        },
        {
          "week": "2026-07-27",
          "commits": 0
        },
        {
          "week": "2026-08-03",
          "commits": 0
        },
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
        }
      ]
    }
  ],
  "totals": {
    "open_prs": 4,
    "ready_prs": 1,
    "attention_prs": 1,
    "open_stories": 3,
    "open_issues": 5,
    "failures_72h": 1,
    "pct_complete": 60,
    "commits_90d": 66
  },
  "warnings": []
};
