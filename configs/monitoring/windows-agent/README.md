# Wazuh Agent — Windows Employee PC (US-11, #52)

> **User story:** US-11 (#52) — *Suricata IDS & Wazuh SIEM Security Monitoring* (M3).
> **Subtask (@joromanii):** Configure Wazuh agents on the Linux server **and the Windows PC**.

This is the Windows half of the agent subtask. The Linux business server already enrolls as a
Wazuh agent (baked into `docker/Dockerfile.business-server`, reporting to the manager at
`192.168.20.100`). This folder provides the equivalent configuration for the café's **Windows
employee workstation** so endpoint events and file changes reach the same Wazuh SIEM.

## Files

| File | Purpose |
|---|---|
| `ossec.conf` | Wazuh **Windows agent** config: manager connection, enrollment, Windows event-log collection, and FIM on the café order records. |

## What it collects

- **Windows event channels** — `Security`, `System`, `Application`. Security covers logon
  success/failure (ties to the brute-force story, #109) and privilege/service changes.
- **File Integrity Monitoring** — `C:\CafeOrders` (realtime) and the employee's Documents
  folder. These hold the café order/customer records an attacker targets after lateral movement,
  so changes to them are exactly what the SOC wants alerted.

It reports to the manager at `192.168.20.100` over `1514/tcp` and enrolls on `1515` — the same
transport the manager config (`configs/monitoring/wazuh_ossec.conf`) already accepts.

## Install & enroll (on the real Windows PC)

Run in an elevated PowerShell. This matches the manager/version (`4.9.2`) used across the lab.

```powershell
# 1. Download and install the agent, pre-seeding the manager + agent name
Invoke-WebRequest -Uri "https://packages.wazuh.com/4.x/windows/wazuh-agent-4.9.2-1.msi" `
  -OutFile "$env:TEMP\wazuh-agent.msi"
msiexec.exe /i "$env:TEMP\wazuh-agent.msi" /q `
  WAZUH_MANAGER="192.168.20.100" WAZUH_AGENT_NAME="swagpc-employee" WAZUH_REGISTRATION_SERVER="192.168.20.100"

# 2. Drop this repo's config into place
Copy-Item ".\ossec.conf" "C:\Program Files (x86)\ossec-agent\ossec.conf" -Force

# 3. Start the agent service
Start-Service -Name WazuhSvc
```

## Verify

On the Wazuh manager:

```bash
docker exec swagpc-wazuh /var/ossec/bin/agent_control -l
```

**Pass criterion:** `swagpc-employee` is listed as **Active**. Then trigger an event (a failed
logon, or edit a file under `C:\CafeOrders`) and confirm a corresponding alert appears in the
Wazuh dashboard / `logs/alerts/alerts.log`.

## Simulation note (honest scope)

The lab models the "Windows employee PC" with an **Alpine container** (`swagpc-workstation`), and
Alpine is not a supported Wazuh agent platform, so this `ossec.conf` and the steps above are the
**real-Windows equivalent** — the configuration a graded Windows endpoint would use — rather than
something installed into the Alpine stand-in. This mirrors the approach taken for the Windows
endpoint-hardening work (`defense/endpoint-hardening/README.md`), where the iptables container
stands in for Windows Defender Firewall and the real PowerShell equivalent is documented
alongside.

## Known gap (not this subtask)

The `dashboard` service points at `https://wazuh:9200`, but the stack has no `wazuh-indexer`
(OpenSearch) service, so the dashboard UI cannot reach an indexer yet. That is the SIEM
indexer/dashboard wiring, separate from agent configuration; flagged here for the US-11
dashboard-verification subtask rather than changed in this PR.
