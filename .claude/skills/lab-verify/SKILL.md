---
name: lab-verify
description: Run the SwagPc Café lab verification checks (workstation-to-server connectivity, network segmentation, WAF) against the local Docker lab only, and save each result as evidence. Use when asked to verify the lab, re-test a defense, or produce before and after evidence.
---

# Lab verification

Follow the root rules in `CLAUDE.md`, especially "Authorized Lab and Security Testing".

## Scope: check before running anything

- Targets are only the local Docker lab subnets: Guest `192.168.10.0/24`, Business `192.168.20.0/24`, and `192.168.30.0/24` in the segmented layout (`docker/docker-compose.segmented.yml`).
- The checks send attack traffic (ping, port scans, SQL injection and command injection test payloads) from the `swagpc-kali` container to lab containers. Never point them at any other host or network.
- If the user has not already confirmed in this conversation which checks to run, list them and confirm first.
- Stop and ask if a command would reach anything outside the lab, or if starting the lab would mean changing the host's Docker or security settings.

## Steps

1. Check the lab is up: `bash lab.sh status`. If services are missing, ask before starting them. `bash lab.sh start` builds images and downloads packages.
2. Run each check through the evidence helper so the result is saved (see the `evidence-capture` skill):

   | Check | Story | Needs | Command |
   |---|---|---|---|
   | Workstation to business server | US-4 (#45) | `business-server`, `workstation` | `sh scripts/testing/verify-workstation-to-server.sh` |
   | Segmentation blocks Guest to Business | US-8 (#49) | segmentation applied (`bash lab.sh defend`) | `bash scripts/testing/verify-defenses.sh` |
   | WAF blocks SQL injection and command injection | US-10 (#24, #7) | `firewall dvwa kali waf` running | `bash scripts/testing/verify-waf.sh` |

   Example:

   ```sh
   sh scripts/capture-evidence.sh verification us8-segmentation-verify "US-8 (#49) - Segmentation re-test" bash scripts/testing/verify-defenses.sh
   ```

3. If a defense has to be turned off for a before and after comparison (`bash lab.sh undefend`), say so, and turn it back on afterwards (`bash lab.sh defend`).
4. Report each check as PASS, FAIL, BLOCKED (could not run) or NOT RUN, with its evidence file path. Do not call a check verified without a saved evidence file.
5. Update the Defense Test Matrix only to match what the evidence shows. Use the `docs-sync` skill.

## Known gaps

- `verify-defenses.sh` Test 2 can report a false negative (issue #64).
- The "Windows employee PC" is an Alpine container, so endpoint checks prove the Linux equivalent only.
