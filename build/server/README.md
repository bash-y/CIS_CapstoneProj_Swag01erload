# Café Business Server (Ubuntu) — US-4

> **User story:** US-4 (#45) — *Café Business Server & Windows Workstation Deployment* (M2).
> **Subtasks (@bash-y):** *Deploy Ubuntu Linux server VM hosting business services* · *Verify employee workstation connectivity to the business server.*

## What this is

The **internal** café operations server: an Ubuntu host on the Business network (`192.168.20.20`) that serves internal business services (operations portal + daily orders export) to authorized Business-network endpoints such as the employee workstation.

It is **distinct** from the existing `dvwa` service (`192.168.20.10`), which is the intentionally-vulnerable *public-facing* café web app used as the attack target. US-4 calls for a dedicated business server, so this adds one rather than reusing DVWA.

## Deployment

Defined as the `business-server` service in [`docker/docker-compose.yml`](../../docker/docker-compose.yml), built from [`docker/Dockerfile.business-server`](../../docker/Dockerfile.business-server):

- **Base image:** `ubuntu:22.04`
- **Build:** installs `python3`/`curl` and **`COPY`s** the content from `build/server/www/` into the image. Content is **baked into the image, not bind-mounted** — so the service needs no Docker Desktop host file-sharing config and runs portably on macOS/Windows/Linux.
- **Address:** `192.168.20.20` (Business network). Published to the host as `127.0.0.1:8090` for local inspection only (not required for intra-lab use).
- **Serves:** `python3 -m http.server 80`.

Bring it up with the rest of the lab:

```bash
bash lab.sh start          # builds and starts all services
docker compose -f docker/docker-compose.yml ps swagpc-business-server
```

## Files

| File | Purpose |
|---|---|
| `../../docker/Dockerfile.business-server` | Builds the server image (installs runtime, copies content). |
| `www/index.html` | Internal business operations portal. |
| `www/orders.csv` | Sample business data (daily orders export). |

## Verify workstation → server connectivity (US-4)

With the lab running:

```bash
sh scripts/testing/verify-workstation-to-server.sh
```

Runs three checks **from the workstation** (`192.168.20.25`) against the server (`192.168.20.20`): ICMP ping, TCP 80, and an HTTP fetch of the business portal. These are container-to-container over the business network and do not depend on the host port publish.

**Pass criterion (baseline build):** all three PASS — both hosts are on the Business network with no host firewall between them. (After US-9 endpoint hardening, inbound to the *workstation* is restricted, but the workstation's outbound connection to the server still succeeds.)

## Verification status

- ✅ `docker compose config` parses cleanly.
- ✅ The `swagpc-business-server` image **builds successfully** (`docker compose build business-server`) on Docker Desktop.
- ✅ Scripts pass `bash -n` / `sh -n`.
- ✅ **Live run recorded:** `verify-workstation-to-server.sh` passed on 2026-10-27 (Docker Desktop 4.48.0, macOS 13.7.8): ping, TCP 80 and the HTTP business portal all PASS. Evidence: [`evidence/build/us4-workstation-to-server.txt`](../../evidence/build/us4-workstation-to-server.txt).
- ⚠️ **Build needs outside package hosts.** The business-server image installs the Wazuh agent from `packages.wazuh.com`, and the compose `workstation` installs curl and netcat from `dl-cdn.alpinelinux.org`. A host that can't reach those hosts fails at those steps (seen 2026-11-02 in a sandbox whose egress policy returns 403 for `packages.wazuh.com` and cannot reach the Alpine CDN).
