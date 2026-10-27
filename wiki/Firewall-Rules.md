# Firewall Rules

> Issue #22: *Document Firewall Rules*. Captured live on 2026-10-27 from the lab (Docker Desktop 4.48.0), with the rules copied from the scripts that set them.

The network firewall is modeled by the `swagpc-firewall` container (Alpine + iptables), standing in for pfSense. It routes between the Guest network (`192.168.10.0/24`, router address `192.168.10.254`) and the Business network (`192.168.20.0/24`, router address `192.168.20.254`).

---

## 1. Undefended state (the baseline)

Set by the compose entrypoint, and by `defense/firewall/disable-segmentation.sh`.

```
Chain INPUT   (policy ACCEPT)
Chain FORWARD (policy ACCEPT)   no rules
Chain OUTPUT  (policy ACCEPT)
```

- `net.ipv4.ip_forward = 1`: the container routes packets between the two networks.
- **Everything is allowed.** Any Guest host can reach any Business host on any port. This is the flat network the attacks run against.

---

## 2. Defended state (after segmentation)

Applied by `defense/firewall/enable-segmentation.sh`. It flushes FORWARD, then adds these rules in order:

| # | Chain | Rule | Purpose | Packet counters at capture |
|---|---|---|---|---|
| 1 | FORWARD | `-m state --state ESTABLISHED,RELATED -j ACCEPT` | Return traffic for sessions that started legitimately | 0 pkts |
| 2 | FORWARD | `-s 192.168.10.0/24 -d 192.168.20.0/24 -j DROP` | **Block Guest → Business** | 0 pkts (see note) |
| 3 | FORWARD | `-j ACCEPT` | Allow everything else, including Business → Internet | 0 pkts |

Verified live, after `enable-segmentation.sh`:

```
Chain FORWARD (policy ACCEPT)
 ACCEPT  all  state RELATED,ESTABLISHED
 DROP    all  192.168.10.0/24 -> 192.168.20.0/24
 ACCEPT  all  0.0.0.0/0 -> 0.0.0.0/0
```

The counters read 0 because this capture ran before any attack traffic. The blocked traffic is confirmed by the attack re-tests (ping 100% loss, TCP timeout), recorded in `evidence/verification/` on PR #65 until that merges.

**Note:** the DROP rule has **no `LOG` rule** in front of it. Blocked attempts are not logged at the firewall. This matches the gap in `BASELINE.md` (finding 1), and the US-8 requirement is "denied **and** logged".

---

## 3. Allowed ports and services

**The network firewall does not filter by port.** Its rules match by subnet only. So once segmentation is applied:

| Traffic | Allowed? | Rule |
|---|---|---|
| Guest → Business, any port | **No** | Rule 2 (DROP) |
| Business → Guest, replies | Yes, for established sessions | Rule 1 |
| Business → Internet | Yes | Rule 3 (matrix test 4) |
| Guest → Firewall itself | Not filtered | No INPUT rules |

**Services listening on the firewall:** none. The container runs only `apk add`, `iptables` and `tail`, and publishes no host ports.

**Services on the Business network that Guest cannot reach after segmentation:** all of them, because the DROP covers every port. The web app (DVWA, `192.168.20.10:80`) and the workstation (`192.168.20.25`) are both blocked.

---

## 4. Rules changed or added, by control

| Control | Where it runs | What it changes | Story |
|---|---|---|---|
| Network segmentation | `swagpc-firewall` (FORWARD chain) | Adds rules 1–3 above | US-8 (#49) |
| Endpoint host firewall | `swagpc-workstation` (INPUT chain), `defense/endpoint-hardening/harden-workstation-firewall.sh` | Default-deny inbound; allow loopback, established, and `192.168.20.0/24`; LOG + DROP `192.168.10.0/24`; LOG + DROP everything else | US-9 (#50), PR #58 |
| Account and password policy | `swagpc-workstation` | Not a firewall rule. Listed for completeness | US-9 (#50), PR #59 |

The workstation rules, verified live on 2026-10-27:

```
Chain INPUT (policy ACCEPT)
 ACCEPT  all  lo
 ACCEPT  all  state RELATED,ESTABLISHED
 ACCEPT  all  192.168.20.0/24 -> anywhere
 LOG     all  192.168.10.0/24 -> anywhere   prefix "WS-ENDPOINT-DROP-GUEST: "
 DROP    all  192.168.10.0/24 -> anywhere
 LOG     all  anywhere                      prefix "WS-ENDPOINT-DROP-OTHER: "
 DROP    all  anywhere
```

The workstation firewall logs its denies, so it meets the "denied and logged" requirement that the network firewall does not yet meet.

---

## 5. Open items

1. **Add `LOG` to the network DROP rule** so guest attempts are recorded at the firewall. Owner: US-8.
2. **No port-level rules.** If the team wants "allow only 80 from Guest to DVWA" style rules, the segmentation script must be changed. Right now it's all or nothing per subnet.
3. **Revert path.** `defense/firewall/disable-segmentation.sh` returns to the undefended state (rules 1–3 removed, policy ACCEPT).

## Reproduce

```bash
docker exec swagpc-firewall iptables -L -n -v        # current rules
sh defense/firewall/enable-segmentation.sh           # apply segmentation
docker exec swagpc-firewall iptables -L FORWARD -n -v
bash defense/firewall/disable-segmentation.sh        # back to undefended
```
