# Defense Implementation

This section details the defensive controls implemented to eliminate lateral movement, secure endpoints, harden applications, and detect intrusions.

---

## 1. Network Segmentation (pfSense)

* **Control:** Strict rule separation on pfSense interface `GUEST` (`VLAN 10`).
* **Rule Added:**
  * **Action:** `Block & Log`
  * **Interface:** `GUEST`
  * **Protocol:** `Any`
  * **Source:** `Guest net`
  * **Destination:** `Business net`
* **Purpose:** Prevents any guest user from reaching the business subnet (`192.168.20.0/24`).

---

## 2. Windows Endpoint Hardening

* **Controls Applied on Windows Employee PC (`192.168.20.25`):**
  1. **Windows Defender Firewall with Advanced Security:**
     * Inbound rules adjusted to restrict SMB (port 445) and RDP (port 3389) strictly to authorized administrative IPs within VLAN 20.
  2. **Protocol Hardening:**
     * Disabled LLMNR (Link-Local Multicast Name Resolution) via Local Group Policy (`Computer Configuration -> Administrative Templates -> Network -> DNS Client -> Turn off multicast name resolution`).
     * Disabled SMBv1 feature.
  3. **Least Privilege:**
     * Restricted local administrator privileges and enforced complex password policies.

---

## 3. Application Security Hardening

* **Controls Applied to Café Web Portal (DVWA):**
  1. Raised security configuration level to validate and sanitize user inputs.
  2. Implemented reverse proxy / binding restrictions ensuring web management is only accessible via localhost or authorized administrative subnet.

---

## 4. Security Monitoring (Suricata + Wazuh)

* **Suricata IDS:**
  * Configured on the perimeter interface to detect Nmap port scans and malicious HTTP attack payloads.
* **Wazuh SIEM:**
  * Deployed Wazuh agent on the Ubuntu Business Server and Windows Workstation forwarding syslog, event logs, and file integrity data to the Wazuh Manager.
  * Custom rules triggered for repeated failed access attempts and web exploitation signatures.
