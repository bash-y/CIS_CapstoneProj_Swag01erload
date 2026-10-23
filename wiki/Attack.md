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
