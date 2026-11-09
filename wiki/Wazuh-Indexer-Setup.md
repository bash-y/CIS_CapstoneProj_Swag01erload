# Wazuh Indexer Setup — Making the SIEM Dashboard Work (US-11, #52)

> **Owner:** @joromanii (Security-Documentation Lead). **Issue:** US-11 (#52).
> **Status:** **PLAN — not yet integrated, not verified in this environment.** This is a
> documented setup procedure, not a working config. The commands below are adapted from Wazuh's
> official single-node Docker deployment (v4.9) and must be run and verified on a Docker host
> before any of it is called "done." Coordinate with the dashboard-verification subtask (@bash-y)
> before wiring this into `docker/docker-compose.yml`.

## The problem (observed)

The `dashboard` service in [`docker/docker-compose.yml`](../docker/docker-compose.yml) is
configured to reach an indexer:

```yaml
environment:
  - OPENSEARCH_HOSTS=["https://wazuh:9200"]
```

…but there is **no indexer in the stack**. `wazuh` is the **manager** (`wazuh/wazuh-manager`),
which does not expose OpenSearch on `9200`. A full Wazuh SIEM has **three** components; we
currently run only the first two:

| Component | Image | Role | In our stack? |
|---|---|---|---|
| Manager | `wazuh/wazuh-manager:4.9.2` | Receives agent events, runs detection rules, writes `alerts.json` | ✅ yes (`swagpc-wazuh`) |
| Indexer | `wazuh/wazuh-indexer:4.9.2` | OpenSearch store the dashboard queries (`:9200`) | ❌ **missing** |
| Dashboard | `wazuh/wazuh-dashboard:4.9.2` | Web UI (`:5601`) that reads from the indexer | ✅ present but has nothing to read |

**Consequence:** the dashboard UI at `http://localhost:5601` cannot load data. Detection still
works at the manager — alerts are written to `logs/alerts/alerts.{log,json}` and are readable
via `bash lab.sh logs` — so **CLI evidence does not depend on this fix**. This gap only blocks
the *graphical* dashboard.

## Interim (works today, no indexer needed)

For US-11 evidence right now, read alerts from the manager directly:

```bash
bash lab.sh logs
docker exec swagpc-wazuh tail -n 50 /var/ossec/logs/alerts/alerts.log
```

This is the recommended evidence path until the indexer is stood up and verified.

## Full fix (procedure to run and verify on a Docker host)

Three pieces are required: **(A)** generate TLS certificates, **(B)** add the indexer service and
re-point the dashboard, **(C)** ship the manager's alerts to the indexer with Filebeat.

### A. Generate certificates

The indexer, dashboard, and manager's Filebeat all require TLS certs. Use Wazuh's cert tool
(run once; output lands in `configs/monitoring/indexer/certs/`). Create a `config.yml` listing
the three nodes with the lab's Business-net IPs:

```yaml
# configs/monitoring/indexer/config.yml
nodes:
  indexer:
    - name: swagpc-indexer
      ip: 192.168.20.102
  server:
    - name: swagpc-wazuh
      ip: 192.168.20.100
  dashboard:
    - name: swagpc-dashboard
      ip: 192.168.20.101
```

```bash
# Adapted from Wazuh 4.9 docs; verify the tool version matches the images (4.9.2)
curl -sO https://packages.wazuh.com/4.9/wazuh-certs-tool.sh
bash wazuh-certs-tool.sh -A config.yml
# -> produces root-ca, node, admin and dashboard certs under ./wazuh-certificates/
```

### B. Indexer service + dashboard re-point

Add a `wazuh-indexer` service (single-node). **Proposed** definition — validate before use:

```yaml
  wazuh-indexer:
    image: wazuh/wazuh-indexer:4.9.2
    container_name: swagpc-indexer
    hostname: swagpc-indexer
    environment:
      - "OPENSEARCH_JAVA_OPTS=-Xms512m -Xmx512m"
      - node.name=swagpc-indexer
      - discovery.type=single-node
      - bootstrap.memory_lock=true
    ulimits:
      memlock: { soft: -1, hard: -1 }
      nofile:  { soft: 65536, hard: 65536 }
    volumes:
      - indexer_data:/var/lib/wazuh-indexer
      - ../configs/monitoring/indexer/certs:/usr/share/wazuh-indexer/certs:ro
      - ../configs/monitoring/indexer/opensearch.yml:/usr/share/wazuh-indexer/opensearch.yml:ro
    networks:
      business-net:
        ipv4_address: 192.168.20.102
    restart: unless-stopped
```

Then change the dashboard to point at the indexer, not the manager:

```yaml
  dashboard:
    environment:
      - OPENSEARCH_HOSTS=["https://swagpc-indexer:9200"]   # was https://wazuh:9200
      - WAZUH_API_URL=https://swagpc-wazuh
    depends_on:
      - wazuh-indexer
      - wazuh
    volumes:
      - ../configs/monitoring/indexer/certs:/usr/share/wazuh-dashboard/certs:ro
```

Add the named volume: `indexer_data:` under `volumes:`.

### C. Ship manager alerts to the indexer (Filebeat)

The manager image bundles Filebeat but it must be configured with the indexer host + certs and
enabled so alerts flow to `:9200`. This is the step most likely to need iteration — treat it as
the verification focus.

## Verification (what "done" requires)

1. `docker compose -f docker/docker-compose.yml config -q` passes.
2. `wazuh-indexer` reports green: `curl -sk -u admin:<pw> https://localhost:9200/_cluster/health`.
3. Dashboard loads at `http://localhost:5601` and shows agents + alerts.
4. Run an attack (recon/brute/web); the alert appears in the dashboard within ~60s.
5. Capture `evidence/defense/wazuh-alerts.png`. Only then mark matrix row 7 verified.

## Why this is a guide, not a merged compose change

A broken indexer config (wrong certs, memory limits, or Filebeat wiring) would break
`lab.sh start` for the whole team, and none of the above can be verified without a running Docker
host — which this authoring environment does not have. Per the project rules, this is published as
a **labeled plan** so a teammate on a Docker machine can execute and verify it, rather than a
config claimed to work. Once verified live, fold sections B/C into `docker-compose.yml` and update
[`Defense-Test-Matrix.md`](Defense-Test-Matrix.md) row 7.
