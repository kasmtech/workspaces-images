# Security Hardening

Security audit and hardening patches applied to the Career-Box workspace environment. This document covers vulnerabilities found in upstream Kasm workspace scripts and in Career-Box's own components (CoeAdapt Launcher, OpenClaw gateway integration), along with the fixes applied.

All fixes preserve full functionality while closing security gaps. If you discover a vulnerability not listed here, please open a private security advisory on this repository rather than a public issue.

---

## Critical Fixes

### 1. Gateway auth bypass removed
**File:** `src/ubuntu/install/careerclaw/install_careerclaw.sh`, `src/ubuntu/install/careerclaw/custom_startup.sh`

The `--allow-unconfigured` flag was passed to the OpenClaw gateway, allowing it to accept connections without requiring proper configuration or authentication setup. Removed from both the launcher script and the respawn loop.

```diff
- ARGS=${APP_ARGS:-"gateway --allow-unconfigured"}
+ ARGS=${APP_ARGS:-"gateway"}
```

### 2. Passwordless sudo eliminated
**File:** `src/ubuntu/install/dind/install_dind.sh`

`kasm-user` had unrestricted `NOPASSWD: ALL` sudo access — equivalent to full root. Replaced with a random password and scoped sudo to only the binaries that actually need it.

```diff
- echo 'kasm-user:kasm-user' | chpasswd
- echo 'kasm-user ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers
+ KASM_PASS=$(openssl rand -base64 16)
+ echo "kasm-user:${KASM_PASS}" | chpasswd
+ echo 'kasm-user ALL=(ALL) NOPASSWD: /usr/bin/dockerd, /usr/local/bin/dind, /usr/local/bin/dockerd-entrypoint.sh, /usr/sbin/iptables, /usr/sbin/ip6tables' >> /etc/sudoers
```

### 3. VPN credentials secured
**File:** `src/ubuntu/install/vpn/start_vpn.sh`

OpenVPN credentials were written to world-readable files. Now created with `chmod 600` before any secrets are written.

```diff
+ install -m 600 -o kasm-user -g kasm-user /dev/null /home/kasm-user/vpn_credentials
  echo ${USER} > /home/kasm-user/vpn_credentials
  echo ${PASS} >> /home/kasm-user/vpn_credentials
```

---

## High-Priority Fixes

### 4. TLS certificate validation enforced
**File:** `src/ubuntu/install/remmina/install_remmina.sh`

Both VNC and RDP default connection profiles had `ignore-tls-errors=1`, disabling certificate validation and allowing man-in-the-middle attacks on remote desktop connections.

```diff
- ignore-tls-errors=1
+ ignore-tls-errors=0
```

Applied to both `default.vnc.remmina` and `default.rdp.remmina` profiles.

### 5. SMB locked to localhost
**File:** `src/ubuntu/install/smb/install_smb.sh`

Samba was bound to all network interfaces with guest access enabled via `map to guest = bad user`. Three changes:

```diff
- ;   interfaces = 127.0.0.0/8 eth0
- ;   bind interfaces only = yes
+ interfaces = 127.0.0.0/8
+ bind interfaces only = yes
```
```diff
- map to guest = bad user
+ map to guest = never
```
```diff
- usershare allow guests = yes
+ usershare allow guests = no
```

### 6. ADB port restricted to localhost
**File:** `src/ubuntu/install/redroid/custom_startup.sh`

Android Debug Bridge was exposed on `0.0.0.0:5555`, giving any machine on the network a full shell into the Android emulator.

```diff
- -p 5555:5555 \
+ -p 127.0.0.1:5555:5555 \
```

### 7. Tauri updater signature enforcement
**File:** `coeadapt-launcher/src-tauri/tauri.conf.json`

The updater `pubkey` was empty, meaning update packages were not signature-verified. A placeholder now forces a real key to be set before release.

```diff
- "pubkey": ""
+ "pubkey": "REPLACE_WITH_REAL_PUBKEY_BEFORE_RELEASE"
```

> **Action required:** Generate a real keypair with `tauri signer generate` and replace the placeholder before shipping.

---

## Medium-Priority Fixes

### 8. Pipe-to-bash patterns removed
**Files:** `src/ubuntu/install/careerclaw/install_careerclaw.sh`, `src/ubuntu/install/dind/install_dind.sh`

`curl | bash` executes remote code without inspection. Changed to download-then-execute so the script can be audited or cached.

```diff
- curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
+ NODESOURCE_SCRIPT=$(mktemp)
+ curl -fsSL https://deb.nodesource.com/setup_22.x -o "$NODESOURCE_SCRIPT"
+ bash "$NODESOURCE_SCRIPT"
+ rm -f "$NODESOURCE_SCRIPT"
```

```diff
- wget -q -O - https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
+ K3D_SCRIPT=$(mktemp)
+ wget -q -O "$K3D_SCRIPT" https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh
+ bash "$K3D_SCRIPT"
+ rm -f "$K3D_SCRIPT"
```

### 9. Gateway localhost binding enforced at runtime
**File:** `src/ubuntu/install/careerclaw/install_careerclaw.sh`

The launcher now reads `openclaw.json` and refuses to start if `gateway.bind` is anything other than `127.0.0.1`. Prevents config tampering from exposing the gateway to the network.

### 10. OpenClaw config directory hardened
**File:** `src/ubuntu/install/careerclaw/install_careerclaw.sh`

- `~/.openclaw/` set to `chmod 700` (owner-only access)
- `~/.openclaw/openclaw.json` set to `chmod 600` (owner-only read/write)
- CORS restricted to `localhost:18789` and `127.0.0.1:18789` origins only

### 11. Dev dependencies stripped from production image
**File:** `src/ubuntu/install/careerclaw/install_careerclaw.sh`

Added `pnpm prune --prod` and `rm -rf .git` after build to reduce attack surface and image size.

---

## Round 2 — Additional Findings

### 12. Hunchly license key removed from repository
**File:** `src/ubuntu/install/hunchly/license.key`

A license key file was committed to git history. Removed from tracking and added to `.gitignore`. The key still exists in git history — run `git filter-branch` or BFG Repo-Cleaner to purge it before making the repo public.

### 13. CI script SSH key set to chmod 777
**File:** `ci-scripts/test.sh`

The SSH private key used for CI test instances was set world-readable/writable. Fixed to `chmod 600`.

```diff
- chmod 777 $(dirname ${CI_PROJECT_DIR})/sshkey
+ chmod 600 $(dirname ${CI_PROJECT_DIR})/sshkey
```

### 14. CI script disabled SSH host key verification
**File:** `ci-scripts/test.sh`

Six SSH calls used `StrictHostKeyChecking=no`, allowing MITM attacks on CI test infrastructure. Changed to `accept-new` (trusts first connect, rejects changed keys).

```diff
- -oStrictHostKeyChecking=no
+ -oStrictHostKeyChecking=accept-new
```

### 15. Chrome repo on OpenSUSE used HTTP
**File:** `src/ubuntu/install/chrome/install_chrome.sh`

The zypper repository for Chrome used unencrypted HTTP, enabling package tampering via MITM.

```diff
- zypper ar http://dl.google.com/linux/chrome/rpm/stable/x86_64 Google-Chrome
+ zypper ar https://dl.google.com/linux/chrome/rpm/stable/x86_64 Google-Chrome
```

### 16. Remmina RDP gateway transport defaulted to HTTP
**File:** `src/ubuntu/install/remmina/install_remmina.sh`

The default RDP profile forced gateway transport over unencrypted HTTP. Changed to `auto` which prefers HTTPS when available.

```diff
- gwtransp=http
+ gwtransp=auto
```

### 17. CareerClaw bind check hardened against config tampering
**File:** `src/ubuntu/install/careerclaw/install_careerclaw.sh`

The previous check refused to start if bind wasn't `127.0.0.1`, but a TOCTOU race could allow bypass. Now the launcher auto-repairs the config back to `127.0.0.1` before starting, closing the race window.

---

## Known Remaining Issues (upstream / not patchable here)

| Issue | Location | Notes |
|-------|----------|-------|
| Unverified binary downloads (no checksums) | blender, eclipse, gimp, horizon, postman, hunchly install scripts | Upstream Kasm scripts — add SHA256 checks when pinning versions |
| Pipe-to-gpg key imports | signal, terraform, vivaldi install scripts | Standard distro packaging pattern — lower risk since GPG verifies the key itself |
| AWS credentials passed as CLI args in CI | `ci-scripts/test.sh` | Visible in `ps aux` — migrate to IAM roles or CI secret masking |
| OwnCloud config points to `http://192.168.117.130:9999` | `src/ubuntu/install/owncloud/install_owncloud.cfg` | Test/template config — users should override with HTTPS endpoint |

---

## Accepted Risks

| Item | Reason |
|------|--------|
| `--no-sandbox` on Chrome/Chromium | Required inside Kasm containers — the container itself is the sandbox boundary |
| `--privileged` on Redroid container | Required for `binder_linux` kernel access; Android emulation won't function without it |
| KasmVNC on `0.0.0.0:6901` | Intentional — this is the user entry point to the remote desktop, protected by VNC password |
| Docker group membership for kasm-user | Required for DinD functionality; mitigated by scoped sudo and container isolation |

---

## Port Map

| Port | Service | Binding | Auth |
|------|---------|---------|------|
| 18789 | OpenClaw Gateway | `127.0.0.1` | Configured (no longer unconfigured) |
| 6901 | KasmVNC | `0.0.0.0` | VNC password |
| 5555 | ADB (Redroid) | `127.0.0.1` | None (localhost only) |
| 5000 | Cyberbro | `127.0.0.1` | None (localhost only) |
| 5002 | SpiderFoot | `127.0.0.1` | None (localhost only) |
| 8834 | Nessus | `localhost` | HTTPS + Nessus auth |
