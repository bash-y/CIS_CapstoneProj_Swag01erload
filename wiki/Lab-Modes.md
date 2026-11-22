# Lab Modes: Baseline and Defended

> **User story:** US-17 (#127), *Reproducible baseline and persistent defended lab modes* (M3).
> **Status:** implemented. The firewall rules pass a stand-in test (25 of 25 checks). **The change has not been run on the real lab** (see [Verification status](#verification-status)).

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

- **Docker 28 and newer can drop Guest traffic before the firewall sees it.** On a host with bridge netfilter on, Docker adds a rule that drops packets addressed to a container's IP when they arrive from another bridge. The Guest to Business path then fails in the **host**, not in the lab firewall, and a "dropped" result proves nothing. The stand-in test showed this on Docker 29.9.2 (`iptables -t raw` listed `-d <container ip> ! -i <bridge> -j DROP`). Always capture a **baseline that succeeds** (the positive control) next to every "blocked" result. The stand-in test creates its own networks with `com.docker.network.bridge.gateway_mode_ipv4=nat-unprotected` to avoid the filter. The lab's own networks do not set that option, and I did not test whether they need it.
- Building the firewall and workstation images needs the Alpine package CDN (`dl-cdn.alpinelinux.org`), and the business-server image needs `packages.wazuh.com`.

## Verification status

| Check | Result | Evidence |
|---|---|---|
| `docker compose config` parses (base file and the segmented override) | Verified, Docker Compose 5.6.1 | this change |
| Firewall rule logic: defended survives restart and recreation, baseline is explicit, an unknown mode or a missing `NET_ADMIN` fails closed, applying twice is identical | Verified on a **stand-in** topology (Ubuntu containers, private subnets), Linux 6.18, Docker 29.9.2: 25 passed, 0 failed | `evidence/verification/us17-lab-modes-standin-*.txt` |
| The test catches a regression | Verified: with the DROP rule removed, 8 checks fail and the exit code is 1 | session log, not saved as evidence |
| `lab.sh start`, `mode`, `defend`, `undefend` on the **real lab** | **NOT RUN.** The sandbox cannot build the firewall image (Alpine package CDN) or the business-server image (Wazuh repository). | none |
| Guest to Business denial and permitted employee and WAF traffic after a restart of the real lab | **NOT RUN** | none |
| Persistent data (named volumes) kept across a mode switch | **NOT RUN.** Rests on how compose recreates containers, not on a test. | none |
| Suricata and Wazuh behavior in each mode | **NOT RUN** | none |

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
