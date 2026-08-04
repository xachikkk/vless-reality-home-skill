---
name: vless-reality-home-vpn
description: Deploy and operate a home VPN based on VLESS + Reality using a low-cost Ubuntu VPS and macOS split-routing. Use when Codex needs to set up a VLESS Reality server, create a client share link, install a macOS sing-box local proxy, configure PAC-based per-domain routing, troubleshoot Reality handshake errors, or prepare the same setup for another device before moving the VPN to a router.
---

# VLESS Reality Home VPN

## Core Workflow

Use this skill to reproduce a proven setup:

1. VPS: Ubuntu 24.04, public IPv4, port `443/tcp`.
2. Server core: `sing-box` VLESS inbound with Reality.
3. Reality handshake target: start with `www.apple.com:443`. In testing, `www.microsoft.com` produced `REALITY: processed invalid connection`; switching to Apple fixed the handshake.
4. Client core: `sing-box` on macOS with a local mixed proxy at `127.0.0.1:7890`.
5. Split routing: enable macOS HTTP/HTTPS proxy to `127.0.0.1:7890`; `sing-box` sends chosen domains through VLESS and sends other traffic direct. PAC may stay enabled as an extra hint, but do not rely on PAC alone.
6. Router phase: postpone until the computer setup is verified.
7. Router target: for Cudy WR3000S, prefer OpenWrt 24.10.5+ and the router installer in `scripts/install_openwrt_router.sh`. Read `references/cudy-wr3000s-openwrt.md` first.

Never ask the user to paste permanent passwords or tokens. Prefer SSH keys. If a password has already been disclosed, add key access, disable password SSH login, and ask the user to rotate the root password in the provider panel.

## Quick Commands

Read `references/operations.md` before making live changes.

Server setup from a trusted local machine:

```bash
./scripts/install_server.sh root@SERVER_IP
```

macOS client setup from a VLESS link:

```bash
./scripts/install_macos_client.sh 'vless://...'
```

Add or replace split-routing domains:

```bash
./scripts/set_domains.sh api.ipify.org ipinfo.io openai.com chatgpt.com telegram.org t.me youtube.com youtu.be instagram.com
```

For common blocked/restricted service domain sets, read `references/blocked-services.md` and add only the services the user explicitly wants.

Verify direct versus proxied routing:

```bash
./scripts/verify_split.sh
```

OpenWrt router setup from the router shell:

```sh
sh /tmp/install_openwrt_router.sh 'vless://...'
```

## Operating Rules

- Keep generated private keys only on the VPS.
- Store the client link in `/root/vless/client-link.txt` on the VPS and avoid publishing it.
- Keep `xray` stopped if this skill installs `sing-box` on port `443`; only one service can bind the port.
- Use `www.apple.com` first. Change the Reality handshake target only if verification fails or the target becomes unsuitable.
- For macOS proxy routing, remember that only applications respecting system proxy settings are covered. Full-device packet routing requires TUN mode or a router.
- For router routing, keep the `vless://...` client link out of GitHub and generated public artifacts. Pass it only at install time or store it only on the router in `/etc/sing-box/config.json`.

## Troubleshooting

If the client sees `EOF` or `connection reset by peer`, check the server log:

```bash
tail -n 80 /var/log/sing-box/sing-box.log
```

If the server says `REALITY: processed invalid connection`, verify:

- client `public_key` matches the server `private_key`;
- client `short_id` matches server `short_id`;
- client `server_name` equals server `tls.server_name`;
- the handshake target is reachable from the VPS;
- macOS and VPS clocks are close, or remove `max_time_difference`.

If values match and it still fails, change the Reality handshake target on both sides; `www.apple.com` was the working target in the reference setup.
