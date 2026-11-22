# Lab Modes: Baseline and Defended

> **User story:** US-17 (#127), *Reproducible baseline and persistent defended lab modes* (M3).
> **Status:** implemented and verified in two partial runs: the firewall rules on a stand-in topology (25 of 25 checks), and the real `lab.sh` and compose file through every mode switch with the real DVWA, WAF and Suricata images (57 of 57). **Not yet run with the real firewall, Kali, workstation and business-server images, or with Wazuh**, and the lab's networks need a workaround on some hosts (see [Environment notes](#environment-notes)).

## The two modes

| Mode | Start it with | What the firewall (the simulated pfSense) does |
|---|---|---|
| **defended** (default) | `bash lab.sh start` or `bash lab.sh defend` | Guest to WAF on tcp 8080 is allowed. Every other Guest to Business packet is logged (`FW-DROP-GUEST:`) and dropped. All other forwarding is allowed. |
| **baseline** | `bash lab.sh start baseline` or `bash lab.sh undefend` | The intentionally vulnerable flat network: all forwarding is allowed. |

The baseline is always an explicit choice. A plain `bash lab.sh start`, and a plain `docker compose up`, give the defended mode. `bash lab.sh attack` refuses to run unless the lab is in the baseline, so a blocked attack is never mistaken for a failed one.

## Commands

```bash
bash lab.sh start [defended|baseline]   # build and start the lab in a mode; waits until the firewall reports it
bash lab.sh mode                        # show the configured mode and the mode the live rules match
bash lab.sh defend                      # switch to defended (recreates the firewall and Suricata)
bash lab.sh undefend                    # switch to baseline (recreates the firewall and Suricata)
```

`LAB_COMPOSE` replaces the compose command `lab.sh` runs (default `docker compose -f docker/docker-compose.yml`). The mode-switch test uses it to add an override file.

Switching modes recreates only the `firewall` and `suricata` containers. Named volumes (Wazuh data and logs, Suricata logs, WAF logs) are kept. `bash lab.sh reset` still deletes volumes (`docker compose down -v`) and is not part of mode switching.

## How the defense survives a restart

- `docker/Dockerfile.firewall` installs iptables when the image is **built**, so no package download happens when the container starts.
- The container's entrypoint runs `defense/firewall/firewall-init.sh apply` on **every** start, restart and recreation. It reads `LAB_MODE` (set by compose, default `defended`) and rebuilds the FORWARD rules from scratch, so applying twice gives the same rules.
- It **fails closed**. The FORWARD policy is set to DROP before anything else. An unknown `LAB_MODE`, or any rule that cannot be applied, exits non-zero. That stops the container, and a stopped router forwards nothing. The container's `restart: unless-stopped` policy retries it.

A plain `docker restart swagpc-firewall` keeps the mode the container was created with. `docker compose up -d` with no `LAB_MODE` set recreates it in the defended mode, which is the safe direction.

## Recovery

| Symptom | Check | Fix |
|---|---|---|
| `lab.sh` reports the firewall did not reach a mode | `docker logs swagpc-firewall` | Fix the error shown, then `bash lab.sh start` or `bash lab.sh defend`. |
| Guest cannot reach the WAF after a switch | `bash lab.sh mode`, then `docker compose -f docker/docker-compose.yml ps` | A restarting firewall forwards nothing. Wait for it, or read its log. |
| Live mode and configured mode differ | `bash lab.sh mode` | Someone ran a runtime script (below). `bash lab.sh defend` or `undefend` resets both to the same mode. |
| Suricata is not capturing | `docker compose -f docker/docker-compose.yml ps suricata` | Suricata shares the firewall's network, so restart it after the firewall: `bash lab.sh defend`. |

## Runtime scripts are not persistent

`defense/firewall/enable-segmentation.sh`, `disable-segmentation.sh`, `route-waf-only.sh` and `firewall-rules.sh` change the live rules only. A restart discards their changes and returns the firewall to its configured mode. Use `lab.sh defend` and `lab.sh undefend` for changes that must last. These scripts are still useful for quick, temporary experiments.

## Pinned images

The external images are pinned by digest in `docker/docker-compose.yml` and the Dockerfiles. The digests were read from Docker Hub on **2026-11-22** with `sh scripts/image-digest.sh <repository> <tag>`. Where the tag is a moving one (`latest`, `kali-rolling`, `nginx`), the digest decides which image runs and the tag is only a label. Refresh a pin by running the script and replacing the digest.

| Image | Tag | Digest |
|---|---|---|
| `alpine` (firewall build, workstation) | `3.24.3` | `sha256:be2656061b536c1883c4034790e21d0a09c5aaaf51968b89368a3c0371ea2c9a` |
| `ubuntu` (business server build) | `22.04` | `sha256:f64b2ffc2f10ab8f8505aa56b2664bd846cbb9df87c7e2532e30f7667021c0e6` |
| `kalilinux/kali-rolling` | `latest` | `sha256:69a9a33d98a584a537bd0f7144d20c3b6d23f3bafa9ffcf0cadf4c5f186d02ff` |
| `vulnerables/web-dvwa` | `latest` | `sha256:dae203fe11646a86937bf04db0079adef295f426da68a92b40e3b181f337daa7` |
| `owasp/modsecurity-crs` | `nginx` | `sha256:697812147e7eada5c668e9728c6439d4663476c69f68635d24fb7878aac0f26a` |
| `wazuh/wazuh-manager` | `4.9.2` | `sha256:b906ebfc77d78446e9b676e1a0b3cd78e2bf3ac2341688f1726b09c29e0aa826` |
| `wazuh/wazuh-dashboard` | `4.9.2` | `sha256:7622129f46c44f9fceb06a5e3ef7366f965e45aac60da1bafd828705e582100a` |
| `jasonish/suricata` | `latest` | `sha256:d5a3a1785299ab40918d465e54fedf8e3afeeedba76bb64b0cc74dbc20bda2c3` |

These are the images the tags pointed to on that date. Earlier lab evidence was captured on whatever those tags pointed to at the time, so a pinned image may differ from the one behind older evidence. The images were **not** started or tested together in one lab run. Only the Ubuntu image was run, in the stand-in test.

Not pinned: the Wazuh agent package inside the business-server image (version-pinned at `4.9.2-1` already) and the packages `apt` and `apk` install at build time.

## Environment notes

- **Docker 28 and newer can block the Guest path on the host, even in baseline.** On a host with bridge netfilter on, Docker adds a rule that drops packets addressed to a container's IP when they arrive from another bridge. The Guest to Business path then fails in the **host**, not in the lab firewall. Observed on Docker 29.9.2 with the lab's own networks (real `lab.sh start baseline`): Kali got no answer from the WAF, DVWA or the business server, while the workstation inside Business reached all three, and `iptables -t raw -S PREROUTING` listed `-d 192.168.20.x ! -i <bridge> -j DROP` for every Business address ([evidence](../evidence/verification/us17-docker29-baseline-blocked-20261122T230710Z.txt)). The earlier lab evidence from Docker Desktop 4.48.0 (engine 28.5.1) shows the path working, so this depends on the host. Always capture a **baseline that succeeds** (the positive control) next to every "blocked" result: on an affected host a "dropped" result proves nothing.
- **Workaround, tested on Docker 29.9.2 on Linux only.** Put this in an override file, for example `lab-networks.override.yml`, run `bash lab.sh stop` so the networks are recreated, then start with `LAB_COMPOSE="docker compose -f docker/docker-compose.yml -f lab-networks.override.yml" bash lab.sh start baseline`:

  ```yaml
  networks:
    guest-net:
      driver_opts:
        com.docker.network.bridge.gateway_mode_ipv4: nat-unprotected
    business-net:
      driver_opts:
        com.docker.network.bridge.gateway_mode_ipv4: nat-unprotected
  ```

  The committed compose file does not set this option, because an older Docker engine may reject it. I did not test that.
- Building the firewall and workstation images needs the Alpine package CDN (`dl-cdn.alpinelinux.org`), and the business-server image needs `packages.wazuh.com`.

## Verification status

| Check | Result | Evidence |
|---|---|---|
| `docker compose config` parses (base file and the segmented override) | Verified, Docker Compose 5.6.1 | this change |
| Firewall rule logic: defended survives restart and recreation, baseline is explicit, an unknown mode or a missing `NET_ADMIN` fails closed, applying twice is identical | Verified on a **stand-in** topology (Ubuntu containers, private subnets), Linux 6.18, Docker 29.9.2: 25 passed, 0 failed | `evidence/verification/us17-lab-modes-standin-*.txt` |
| The tests catch a regression | Verified: with the DROP rule removed, the stand-in test fails 8 checks and the real-compose test fails 14, both with exit code 1 | session log, not saved as evidence |
| `lab.sh start [mode]`, `mode`, `defend`, `undefend`, `stop` and the `attack` guard with the real compose file; defended allows Guest to the WAF and blocks DVWA direct and Business, baseline is flat, employee (Business-internal) paths work in every mode; all of it after a mode switch, a firewall restart, and a stop and start; a plain start is defended | Verified with the **real DVWA, WAF and Suricata** images and the real `firewall-init.sh`. The firewall, Kali, workstation and business server are Ubuntu stand-ins and Wazuh is off. 57 passed, 0 failed on Linux 6.18, Docker 29.9.2, Compose 5.6.1, with the Docker 28 workaround above | `evidence/verification/us17-lab-switch-realcompose-20261122T230745Z.txt` |
| Data in a named volume kept across mode switches and across stop and start | Verified (a marker file in a named volume) | same file |
| DVWA's database across `lab.sh stop` and `start` | **Not kept, by configuration. Not tested.** The DVWA image declares no volume and the compose file adds none, so the database lives in the container, and a new container starts with a fresh one (create it again at `/setup.php`). Mode switches do not touch DVWA. | none |
| Committed lab networks in baseline on Docker 29.9.2 | **Guest cannot reach Business even in baseline** without the workaround | `evidence/verification/us17-docker29-baseline-blocked-20261122T230710Z.txt` |
| The real firewall, Kali, workstation and business-server images; Wazuh; Suricata alerts in each mode; macOS and Windows Docker Desktop | **NOT RUN.** The sandbox cannot build the Alpine, Kali and Wazuh-agent images. | none |

## Verify on the real lab

Run these on a Docker host, then save each result with `sh scripts/capture-evidence.sh` (see the `evidence-capture` skill). Record the Docker and Compose versions, which `capture-evidence.sh` writes into the evidence header.

```bash
bash lab.sh start defended && bash lab.sh mode            # configured=defended live=defended
bash scripts/testing/verify-defenses.sh                    # Guest to Business blocked (note issue #64)
bash scripts/testing/verify-waf.sh                           # Guest to WAF allowed, attacks blocked

docker restart swagpc-firewall && sleep 5 && bash lab.sh mode      # still live=defended
bash lab.sh defend && bash lab.sh mode                              # recreation, still defended
docker volume ls | grep -E "wazuh|suricata|waf"                     # the named volumes are still there

bash lab.sh undefend && bash lab.sh mode                           # baseline, deliberate
sh scripts/testing/verify-workstation-to-server.sh                  # permitted employee traffic
bash lab.sh defend
```

To run the stand-in test on any Docker host: `bash scripts/testing/test-lab-modes.sh`.

To run the real `lab.sh` and compose file through every mode switch (stand-ins for the firewall, Kali, workstation and business server; real DVWA, WAF and Suricata): `bash scripts/testing/test-lab-switch.sh`. Stop the lab first. The test refuses to run if any `swagpc-*` container or the `guest-net` or `business-net` network exists, runs under its own compose project name (`labswitch`), and removes what it created. On an affected Docker 28 host it needs the workaround above, which its override file already includes.
