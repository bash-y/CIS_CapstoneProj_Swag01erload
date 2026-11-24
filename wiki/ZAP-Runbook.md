# ZAP Runbook: OWASP ZAP in the Café Lab

> **User stories:** US-23 (#134) owns this runbook. It documents the runner from US-19 (#130) and will document the scans from US-20 (#131) and US-21 (#132).
> **Status: partial draft, not complete.**
> - Sections 1 to 6 and 9 describe the runner that exists. They were run in a **Linux sandbox only** (see [Verification status](#10-verification-status)).
> - Sections 7 and 8 are **planned**: the authenticated scan (US-20) and the bounded active scans (US-21) are not implemented, and nothing here has been run for them.
> - **No other teammate has followed this runbook yet.** Issue #134 cannot close until one does and the reproduction record in section 11 is filled in.

## 1. What this is and what it is not

ZAP is a web application scanner. In this lab it plays the attacker's web tooling, from the Guest network, so a scan travels the same path as the café attacker: through the firewall and, in the defended mode, the WAF.

- It is **attack tooling**. Use it only against the targets on `configs/zap/targets.allowlist`, which are local lab addresses.
- Setting it up runs **no scan**. Confirm the exact targets and the plan before any active scan.
- It is **opt-in**. It starts only with the `zap` compose profile, so a normal `bash lab.sh start` does not start it.

## 2. Prerequisites and tested versions

| Item | Value | Tested |
|---|---|---|
| Docker engine / Compose | 29.9.2 / 5.6.1 | Yes, on Linux 6.18 (sandbox) |
| Docker Desktop on macOS or Windows | not recorded | **No** |
| Disk | about 5 GB free; the ZAP image is 3.7 GB | n/a |
| Image | `zaproxy/zap-stable:2.17.0@sha256:9624669db72f54d86c4b46a7064518bd9bf79d8c61a4c31befa9923489f328af` | Pulled and run |
| Add-ons | 49, listed with versions in `configs/zap/addons.txt` (recorded 2026-11-22) | Compared by `check-ready.sh` |
| Network | Docker Hub for the image. Nothing else at run time. | n/a |

The image is pinned by digest. To change it, update the digest in `docker/docker-compose.yml` (read it with `sh scripts/image-digest.sh zaproxy/zap-stable <tag>`), regenerate `configs/zap/addons.txt`, and review both in a pull request.

## 3. Where the scanner sits

```text
Guest network 192.168.10.0/24                          Business network 192.168.20.0/24
  kali      192.168.10.50                                 waf   192.168.20.15  (port 8080)
  zap       192.168.10.60   --->  firewall  --->           dvwa  192.168.20.10
                              192.168.10.254 / 192.168.20.254
                              (simulated pfSense: the rules of the current lab mode)
```

- The scanner is on the Guest network **only**. It is never attached to the Business network. Its one route to Business goes through the firewall at `192.168.10.254`.
- It publishes **no ports** and starts **no ZAP API**. Scans are started on purpose with `docker exec`.
- It starts as root with five capabilities (`CHOWN`, `NET_ADMIN`, `SETUID`, `SETGID`, `SETPCAP`) to set up its route and report folder, then runs as the `zap` user (uid 1000) with **no** capabilities and `no-new-privileges` (`scripts/zap/zap-init.sh`).
- The firewall is the simulated pfSense: an Alpine container running iptables, not pfSense.

## 4. Commands

```bash
# start the runner (opt-in)
docker compose -f docker/docker-compose.yml --profile zap up -d zap

# check it (needs no scan; --no-lab skips the checks that need the firewall, WAF and DVWA)
bash scripts/zap/check-ready.sh            # with the lab running
bash scripts/zap/check-ready.sh --no-lab   # runner only

# stop it
docker compose -f docker/docker-compose.yml --profile zap stop zap
```

Commands inside the container run as `zap`: `docker exec -u zap swagpc-zap <command>`. Without `-u zap`, `docker exec` runs as root, which has no capabilities here and cannot write to the report folder.

**Reports** live in the `zap_reports` volume, mounted at `/zap/wrk` (named `docker_zap_reports` when the lab is started from the repo's `docker` folder). Copy them out with:

```bash
docker cp swagpc-zap:/zap/wrk/. ./zap-reports/
```

Review a report before it goes into `evidence/`. A report can contain session cookies, tokens and page content. Do not commit credentials or tokens.

## 5. Scope: what a scan may touch

`configs/zap/targets.allowlist` lists the exact URLs a scan may touch. The checker enforces these rules:

- Hosts are IPv4 addresses inside `192.168.10.0/24`, `192.168.20.0/24` or `192.168.30.0/24`. Hostnames, wildcards and every other address are refused.
- A target is covered only if its scheme, host and port match an entry exactly and its path is under the entry's path.
- URLs with credentials in them are refused.

```bash
python3 scripts/zap/zap_check.py target http://192.168.20.15:8080/dvwa/login.php   # OK, exit 0
python3 scripts/zap/zap_check.py target http://8.8.8.8/                            # REFUSED, exit 2
python3 scripts/zap/zap_check.py regexes                                           # ZAP context include regexes
python3 scripts/zap/zap_check.py config                                            # compose service and allowlist
```

**Excluding external navigation and redirects** is the scan configuration's job (US-20): it must use the include regexes from `zap_check.py regexes` and exclude everything else, so a link or redirect to another host is not followed. This is a rule for that configuration. It is **not tested** yet, because no scan configuration exists.

`zap_check.py config` also fails if the compose service is changed in an unsafe way: not opt-in, image not pinned, any network but `guest-net`, a published port, a privileged or host-mode setting, a capability outside the five above, a writable bind mount, the Docker socket, or no report volume.

## 6. Modes and the Guest path

The firewall has two modes (see [Lab Modes](Lab-Modes.md)). From the scanner:

| Target | Defended mode | Baseline mode |
|---|---|---|
| WAF `http://192.168.20.15:8080/` | reachable | reachable |
| DVWA direct `http://192.168.20.10/` | blocked | reachable |

`check-ready.sh` (without `--no-lab`) tests this from inside the scanner container, which is the only valid proof of Guest reachability. A published host port such as `localhost:8081` is **not** proof. **This lab-dependent part has not been run** (see section 10).

On Docker 28 or newer with bridge netfilter on, the host can drop Guest traffic before the firewall sees it. Then "blocked" results prove nothing. The WAF check is the positive control: if the scanner cannot reach the WAF in either mode, fix that before reading any other result. See [Lab Modes](Lab-Modes.md), Environment notes.

## 7. Authenticated scanning and secrets (PLANNED, US-20)

Not implemented. The approach this runbook will document once US-20 lands:

- The DVWA login for the scan context is passed **at run time** (for example with `docker exec -e`), never written into a committed file, automation plan or report.
- The scan runs against the allowlist only, with the include regexes from section 5.
- Expected success and failure outputs, report paths and the reviewed commands come from US-20's actual configuration and evidence, not from this draft.

## 8. Scan limits, passive and active scans (PLANNED, US-21)

Not implemented. A **passive** scan only examines the requests and responses ZAP already sees, such as those from a spider. An **active** scan sends attack payloads to the target. That is general ZAP behavior, not a lab result.

- Active scans need the exact targets and the plan confirmed first, and run only against the allowlist.
- US-21 defines the limits (duration, request rate, scope), and a before-and-through-the-WAF comparison. They are not defined yet.

## 9. Stop, restart, restore, data

- **Stop and start** the runner with `docker compose ... --profile zap stop zap` and `start zap`. The init script runs again on each start and re-adds the route.
- **Recreate** it with `docker compose ... --profile zap rm -sf zap` then `up -d zap`.
- **Reports survive** stop, start and recreation. The volume is only removed by `docker compose down -v`, `bash lab.sh reset` or `docker volume rm`. **This runbook does not prescribe any of those.** Copy reports out first, and get separate authorization before deleting a volume.
- **Restoring the lab mode** is independent of the scanner. `bash lab.sh mode` shows the mode, `bash lab.sh defend` returns to defended, and `bash lab.sh undefend` switches to the baseline. Switching recreates only the firewall and Suricata. The scanner keeps running and keeps its route.

## 10. Verification status

| Check | Result | Evidence |
|---|---|---|
| Compose service is opt-in, Guest-only, pinned, unpublished, minimal capabilities; allowlist valid | Verified by `zap_check.py` and 10 unit tests (18 unsafe changes and 11 bad allowlist entries, each caught) | `evidence/build/us19-zap-scope-checks-20261122T203752Z.txt` |
| Runner starts from the real compose file; runs as zap with no capabilities; one Guest interface; route to Business via the firewall; report folder writable; ZAP 2.17.0; 49 add-ons match | Verified on Linux 6.18, Docker 29.9.2 | `evidence/build/us19-zap-runner-lifecycle-20261122T203614Z.txt` |
| Stop, start and recreation keep the report file and leave a sibling volume untouched | Verified in the same run (14 of 14 checks) | same file |
| `check-ready.sh` fails on an extra network or a stopped container | Verified by hand, not saved as evidence | session log |
| Scanner reaches the WAF through the firewall; DVWA direct blocked in defended mode and reachable in baseline | **NOT RUN.** The sandbox cannot build the firewall image (Alpine package CDN). | none |
| macOS and Windows Docker Desktop | **NOT RUN** | none |
| Authenticated baseline scan, bounded active scans, expected outputs | **NOT IMPLEMENTED** (US-20, US-21) | none |

## 11. Reproduction record (required by #134)

Another teammate follows sections 2 to 6 and 9 in an isolated lab, then fills in a row. Scan sections can be added as US-20 and US-21 land.

| Reviewer | Commit | Environment (OS, Docker, Compose) | Commands run | Actual outcome |
|---|---|---|---|---|
| *not yet done* | | | | |

## 12. Troubleshooting

| Symptom | Likely cause | What to do |
|---|---|---|
| `check-ready.sh` says the container is not running | The runner was never started, or exited | Start it (section 4), then `docker logs swagpc-zap` |
| `docker compose up` says `swagpc-zap` already exists | A previous runner is still there | `docker compose ... --profile zap stop zap`, then start again |
| The image pull is slow or fails | The image is 3.7 GB, or Docker Hub is blocked | Check the network. The pinned digest is in section 2. |
| "expected one network interface" | Something attached the scanner to a second network | Remove it: `docker network disconnect <network> swagpc-zap` |
| "report folder is not writable" | The init script did not finish | `docker logs swagpc-zap`, then restart the runner |
| Add-on versions differ | The image changed | Compare with `configs/zap/addons.txt` and review the new image in a pull request |
| Scanner cannot reach the WAF | Firewall not running, or the host drops the traffic (section 6) | `bash lab.sh mode`, then read the Docker 28 note in [Lab Modes](Lab-Modes.md) |
