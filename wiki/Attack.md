# Undefended Attack Demonstration

This section documents the baseline attacks executed before implementing defensive controls. Demonstrating this phase proves the vulnerability exists and establishes the baseline for verification.

---

## 1. Attack 1: Network Reconnaissance & Service Discovery

* **Attacker Position:** Kali Linux (`192.168.10.50`) on Guest VLAN 10.
* **Objective:** Scan the network to discover live hosts and open ports across the café infrastructure.

### Command Executed:
```bash
# ARP scan to detect live nodes across subnets
arp-scan --localnet

# Nmap sweep across business subnet
nmap -sS -sV -O -p- 192.168.20.0/24
```

### Result (Undefended):
* Both `192.168.20.10` (Ubuntu Server) and `192.168.20.25` (Windows Employee PC) respond to ICMP and ARP.
* Port 80 (HTTP) detected open on `192.168.20.10`.
* Port 445 (SMB) and 3389 (RDP) detected open on `192.168.20.25`.
* **Evidence:** *(Place terminal output / screenshot in `evidence/attack/nmap-recon-undefended.png`)*

---

## 2. Attack 2: Web Application Exploitation (DVWA)

* **Objective:** Exploit a web vulnerability on the internal business server from the guest network position.

### Command / Exploit:
* Attacker accesses `http://192.168.20.10:8080` (DVWA) from Kali browser.
* Command Injection payload executed against the vulnerable web form:
  ```text
  127.0.0.1; cat /etc/passwd
  ```

### Result (Undefended):
* The vulnerable application executes the command and returns `/etc/passwd` contents to the browser.
* **Evidence:** *(Place screenshot in `evidence/attack/dvwa-exploit-undefended.png`)*

---

## 3. Attack 3: Lateral Movement Toward Employee Workstation

* **Objective:** Pivot or initiate connections from the compromised guest position toward the business employee workstation.

### Command Executed:
```bash
# Test SMB reachability
smbclient -L //192.168.20.25/ -N
```

### Result (Undefended):
* Connection established to SMB port on employee PC; IPC$ share listed.
* Demonstrates full lateral reachability from untrusted guest Wi-Fi to internal business endpoints.
* **Evidence:** *(Place screenshot in `evidence/attack/lateral-smb-undefended.png`)*

---

## 4. Attack Scenario Register (issue #2)

Every scenario we demonstrate on the undefended build, with the script or story that runs it and the defense it is re-tested against. "Expected" is what the undefended build should show. "Last run" is the 2026-10-27 live result, where we have one.

| # | Scenario | Attacker (Kali `192.168.10.50`) → target | Technique | Script | Story / issue | Expected (undefended) | Last run (2026-10-27) | Re-tested against |
|---|---|---|---|---|---|---|---|---|
| S1 | Network reconnaissance | → `192.168.20.0/24` | ICMP ping sweep and nmap port scan | `scripts/attack/recon-scan.sh` | US-6 (#47) | Hosts `.10`, `.25`, `.254` respond; port 80 open on `.10` | Confirmed: ping replies, nmap finds `.10`, `.25`, `.254` | Matrix row 1 (segmentation) |
| S2 | Web command injection | → DVWA `192.168.20.10:80` | `ip=127.0.0.1;cat /etc/passwd` on the exec form | `scripts/attack/dvwa-exploit.sh` | US-7 (#48); bug #63 | `/etc/passwd` returned in the response | **Not proven.** Payload returned no output. Suspected cause: DVWA security level and DB setup (#63), not yet confirmed | Matrix row 4 (application hardening) |
| S3 | SQL injection | → DVWA `192.168.20.10:80` | Authentication bypass or users-table dump | **None yet** | #6 (bash-y) | Login bypass or data dump succeeds | Not run | **Gap:** no matrix row yet |
| S4 | Lateral reachability to workstation | → `192.168.20.25` | ICMP plus TCP connect to 22, 80, 445 | `scripts/attack/lateral-test.sh` | US-7 (#48) | Ping replies; TCP connects are refused (no listener), but the host is reachable | Ping 3/3 replies and nmap reports the host up. TCP connects were not recorded on the undefended run | Matrix row 5 (endpoint hardening) |
| S5 | SMB share listing | → `192.168.20.25` | `smbclient -L //192.168.20.25/ -N` | **None** (manual command in Attack 3 above) | US-7 (#48) | IPC$ listed | **Contradicted:** the workstation runs no SMB service | **Remove or re-scope** (see §5) |

Scenarios S1, S2 and S4 each have a script. S3 needs a script before it can be run. S5 is written up in Attack 3 but the lab cannot run it as described.

---

## 5. Discrepancies found while defining the scenarios

These are places where this page disagrees with the lab or the scripts. They should be fixed by the story owner, not by this table.

1. **Host address for DVWA.** Attack 2 and the register use `192.168.20.10`. The lab runs DVWA there. The `8080` port in Attack 2 is the host-published port, which only exists on the host, so Kali reaches it on port 80.
2. **"Ubuntu Server" label.** Attack 1 calls `192.168.20.10` the Ubuntu Server. That address is DVWA. The Ubuntu business server is `192.168.20.20` (PR #60).
3. **SMB on the workstation.** Attack 1 and Attack 3 report SMB (445) open and an IPC$ share on `192.168.20.25`. The workstation is an Alpine container with no SMB service, so this cannot reproduce on the current lab. Re-scope to the port-reachability check, or remove it.
4. **Command-injection evidence.** Attack 2 says `/etc/passwd` is returned. The live run returned nothing (#63), so the result is unproven until #63 is fixed.
