# Three-Segment Network Layout

> Issue #8: *Network segmentation + verification*. Captured live on 2026-10-27.
> Opt-in layout: `docker/docker-compose.segmented.yml`. The base layout in `docker/docker-compose.yml` is unchanged and remains the undefended baseline.

## The three segments

| Segment | Network | Hosts | Who can reach it |
|---|---|---|---|
| **Customer ↔ WAF** | `guest-net` `192.168.10.0/24` | Kali (`192.168.10.50`), WAF (`192.168.10.15`) | Guest hosts reach the WAF on port 8080 |
| **WAF ↔ DVWA** | `app-net` `192.168.30.0/24` (new, private) | WAF (`192.168.30.2`), DVWA (`192.168.30.10`) | Only the WAF. The firewall does not route this segment |
| **DVWA ↔ DB** | inside the DVWA container | DVWA's MySQL | Not a separate segment; see Limitations |

DVWA is no longer on the Business network. The Business network still holds the business server, workstation, and Wazuh, but no Guest route reaches them through the WAF.

## Verified (2026-10-27)

Evidence: [`evidence/defense/segmented-networks-20261027T143306Z.txt`](../evidence/defense/segmented-networks-20261027T143306Z.txt) and [`evidence/defense/segmented-verify-20261027T143306Z.txt`](../evidence/defense/segmented-verify-20261027T143306Z.txt).

| Check from Kali (Guest) | Result |
|---|---|
| WAF at `192.168.10.15:8080` | **Reachable** (200) |
| DVWA at `192.168.30.10:80` | **Unreachable** (no route; no response) |
| DVWA MySQL at `192.168.30.10:3306` | **Unreachable** |
| Old DVWA address `192.168.20.10:80` | **Unreachable** (no longer on that network) |
| WAF reaches DVWA on `app-net` | **200** (the proxy path works) |
| `verify-waf.sh` (9 checks, using `WAF_IP=192.168.10.15 DIRECT_IP=192.168.30.10`) | **9 passed, 0 failed, 0 known gaps** |

The old bypass gap is closed by the layout, not by a firewall rule: DVWA has no address Kali can route to.

## Limitations

1. **No separate DB segment.** The lab's database is MySQL inside the DVWA image. Splitting DVWA from its DB needs a separate DB container, which the lab does not have.
2. **Undefended scripts do not run on this layout.** `run-full-attack.sh`, `dvwa-exploit.sh` and `lateral-test.sh` target `192.168.20.10` and will fail. Use the WAF address for the web attacks.
3. **Only port 8080 on the WAF is exposed.** The firewall does not forward Guest traffic to the Business network, so Guest hosts reach nothing else.
4. **The DVWA admin port is still published on the host** as `127.0.0.1:8080`. That is for the local admin path only and is not reachable from the Guest network.

## Run it

```bash
docker compose -f docker/docker-compose.yml -f docker/docker-compose.segmented.yml up -d firewall dvwa kali waf
WAF_IP=192.168.10.15 DIRECT_IP=192.168.30.10 bash scripts/testing/verify-waf.sh
```
