#!/bin/sh
# harden-workstation-accounts.sh
# US-9 (#50) — Endpoint hardening: local account LEAST-PRIVILEGE and PASSWORD
# POLICY on the employee workstation (swagpc-workstation / 192.168.20.25).
#
# Goal: the café employee operates under a non-privileged local account, direct
# root login is locked, and a password aging/length policy is enforced — so a
# compromised employee session does not grant administrative control.
#
# NOTE ON SIMULATION: the "Windows employee PC" is modeled by an Alpine
# container. This script applies the Linux-equivalent controls that busybox +
# the `shadow` package genuinely support. Controls that need PAM/pwquality (full
# complexity rules, lockout) are NOT faked here — they are documented for the
# real Windows host in account-password-policy.md. What this script does is
# really applied and inspectable.

set -e

WS="swagpc-workstation"
EMP="employee"

# Password policy parameters (mirrored to Windows `net accounts` in the doc).
PASS_MAX_DAYS=90    # force rotation every 90 days
PASS_MIN_DAYS=1     # cannot change again for 1 day (anti-cycling)
PASS_WARN_AGE=7     # warn 7 days before expiry
PASS_MIN_LEN=12     # minimum length

echo "=== US-9: Applying least-privilege + password policy on $WS ==="

docker exec "$WS" sh -c "
  set -e

  # shadow provides useradd/usermod/chage/passwd aging (busybox alone is limited).
  if ! command -v chage >/dev/null 2>&1; then
    apk add --no-cache shadow >/dev/null
  fi

  # 1. Password policy defaults for any new/changed account (/etc/login.defs).
  set_def() { key=\$1; val=\$2; \
    if grep -qE \"^\\s*\$key\" /etc/login.defs 2>/dev/null; then \
      sed -i \"s|^\\s*\$key.*|\$key \$val|\" /etc/login.defs; \
    else echo \"\$key \$val\" >> /etc/login.defs; fi; }
  set_def PASS_MAX_DAYS $PASS_MAX_DAYS
  set_def PASS_MIN_DAYS $PASS_MIN_DAYS
  set_def PASS_WARN_AGE $PASS_WARN_AGE
  set_def PASS_MIN_LEN  $PASS_MIN_LEN

  # 2. Least privilege: create a NON-privileged employee account if absent.
  #    No wheel/sudo group membership -> cannot escalate to root.
  if ! id $EMP >/dev/null 2>&1; then
    useradd -m -s /bin/sh -c 'Cafe Employee' $EMP
  fi
  # Ensure the employee is NOT in any admin group.
  for g in wheel sudo root adm; do
    deluser $EMP \$g >/dev/null 2>&1 || true
  done

  # 3. Own the business data as the employee, not root; restrictive perms.
  mkdir -p /home/$EMP/orders
  chown -R $EMP:$EMP /home/$EMP
  chmod 700 /home/$EMP

  # 4. Apply the aging policy to the employee account explicitly.
  chage -M $PASS_MAX_DAYS -m $PASS_MIN_DAYS -W $PASS_WARN_AGE $EMP

  # 5. Restrictive default umask for the employee (027 = no access for 'other').
  if ! grep -q 'umask 027' /home/$EMP/.profile 2>/dev/null; then
    echo 'umask 027' >> /home/$EMP/.profile
  fi

  # 6. Lock direct interactive root login (admin access only via controlled
  #    channels, not a shared root password). docker exec is unaffected.
  passwd -l root >/dev/null 2>&1 || true

  # 7. Lock unused default login accounts to shrink the attack surface.
  for u in games ftp; do
    passwd -l \$u >/dev/null 2>&1 || true
  done
"

echo "[SUCCESS] $WS: non-privileged '$EMP' account in place, root login locked, password policy (max=${PASS_MAX_DAYS}d, min-len=${PASS_MIN_LEN}) enforced."
echo "--- Account summary on $WS ---"
docker exec "$WS" sh -c "echo '[groups for $EMP]'; id $EMP; echo '[password aging for $EMP]'; chage -l $EMP; echo '[root status]'; passwd -S root 2>/dev/null || true"
