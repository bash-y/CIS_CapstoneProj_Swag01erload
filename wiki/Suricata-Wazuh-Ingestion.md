# Suricata → Wazuh Event Ingestion (US-11, #129)

> **Owner:** @joromanii. **Parent:** US-11 (#52). **Status:** config implemented; **live
> ingestion not yet verified** (no Docker host in the authoring environment). Run the validation
> steps below on the lab to confirm and capture evidence.

## Goal

Give Suricata IDS alerts a persistent, explicit path into Wazuh so detections are decoded into
searchable Wazuh alerts — the "Suricata event ingestion" half of #129. (The dashboard/indexer
half is tracked in [`Wazuh-Indexer-Setup.md`](Wazuh-Indexer-Setup.md).)

## Data flow

```
Suricata (sniffs firewall interfaces)
  └─ writes /var/log/suricata/eve.json   (suricata_logs volume)
        └─ shared read-only into the Wazuh manager at /var/log/suricata
              └─ Wazuh logcollector tails eve.json  (<localfile> json)
                    └─ Wazuh Suricata decoder + ruleset → Wazuh alert (alerts.log / indexer)
```

## What changed

| File | Change |
|---|---|
| `configs/monitoring/wazuh_ossec.conf` | Added a `<localfile>` reading `/var/log/suricata/eve.json` as `json`. |
| `docker/docker-compose.yml` | Mounted the existing `suricata_logs` volume into the `wazuh` manager read-only at `/var/log/suricata`. |

Suricata already emits `eve.json` with `alert`, `dns`, `http`, `tls` and `files` event types
(`configs/monitoring/suricata.yaml`), so no Suricata-side change was needed. Wazuh ships built-in
Suricata decoders/rules, so the JSON `alert` events are decoded without custom decoders.

## Why a shared volume (not syslog)

The manager already accepts remote syslog on 1514/udp, but Suricata here runs with
`network_mode: container:swagpc-firewall` and writes to a file. Sharing the `suricata_logs`
volume read-only is the simplest persistent path and keeps eve.json as durable evidence. It is
independent of the custom-rule mount (#123) and the indexer work (#126) — those can land in any
order.

## Validation (run on a Docker host)

```bash
bash lab.sh start
# 1. Manager can see the file
docker exec swagpc-wazuh test -f /var/log/suricata/eve.json && echo "eve.json visible"
# 2. Generate traffic that trips a rule
docker exec swagpc-kali bash /scripts/attack/recon-scan.sh
# 3. Confirm Suricata wrote alerts
docker exec swagpc-suricata tail -n 5 /var/log/suricata/eve.json
# 4. Confirm Wazuh decoded them into alerts
docker exec swagpc-wazuh grep -i suricata /var/ossec/logs/alerts/alerts.log | tail -n 5
```

**Pass criterion:** a Suricata `alert` event in `eve.json` produces a matching Wazuh alert
(same signature/SID, source `192.168.10.50`) within the #107 60-second target. Capture dated
output to `evidence/defense/` (no credentials or sensitive records).

## Known limitations / to verify live

- **File permissions:** `eve.json` must be readable by the Wazuh manager process. If the
  logcollector reports a permission error, confirm Suricata writes world-readable output or align
  the UID — record the resolution here.
- **Dashboard view** of these alerts still depends on the indexer (`Wazuh-Indexer-Setup.md`);
  until then, verify via `alerts.log` as above.
- Hand the captured evidence to #107 for independent end-to-end acceptance.
