---
name: vless-reality-home-vpn
description: Deploy and operate a home VPN based on VLESS + Reality using a low-cost Ubuntu VPS, macOS split-routing, and Cudy WR3000S OpenWrt router transparent FakeIP routing. Use when Codex needs to set up a VLESS Reality server, create a client share link, install a macOS sing-box local proxy, configure PAC-based per-domain routing, configure Cudy WR3000S/OpenWrt so LAN/Wi-Fi devices automatically route selected domains through VLESS, troubleshoot Reality handshake errors, or prepare the same setup for another device.
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
7. Router target: for Cudy WR3000S V1.0, prefer OpenWrt 24.10.5+ and the router installers in `scripts/install_openwrt_router.sh` and `scripts/install_openwrt_transparent_fakeip.sh`. Read `references/cudy-wr3000s-ready-solution.md` before changing a live router.

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

Cudy WR3000S transparent router mode, after proxy mode is verified:

```sh
sh /tmp/install_openwrt_transparent_fakeip.sh
```

## Operating Rules

- Keep generated private keys only on the VPS.
- Store the client link in `/root/vless/client-link.txt` on the VPS and avoid publishing it.
- Keep `xray` stopped if this skill installs `sing-box` on port `443`; only one service can bind the port.
- Use `www.apple.com` first. Change the Reality handshake target only if verification fails or the target becomes unsuitable.
- For macOS proxy routing, remember that only applications respecting system proxy settings are covered. Full-device packet routing requires TUN mode or a router.
- For router routing, keep the `vless://...` client link out of GitHub and generated public artifacts. Pass it only at install time or store it only on the router in `/etc/sing-box/config.json`.
- On Cudy WR3000S, do not tell the user to run `wifi down` while connected by Wi-Fi. Warn before any Wi-Fi or network restart. Prefer `wifi reload`, LuCI, Ethernet, or a planned reboot.
- If both 5 GHz and 2.4 GHz SSIDs should use VLESS routing, verify both `wireless.*.network` values are `lan`. A known bad state is `network='wan wan6'` on the 2.4 GHz SSID.
- OpenWrt `/var/log` is temporary. Ensure the router init script creates `/var/log/sing-box` inside `start_service()` before starting sing-box, otherwise autostart can fail after reboot.
- Telegram and WhatsApp mobile apps can bypass domain rules by connecting directly to service IP ranges. For Cudy WR3000S transparent mode, keep Telegram CIDRs and main Meta/Facebook CIDRs in `scripts/install_openwrt_transparent_fakeip.sh`, route them through `vless-fakeip0`, and document the mobile-app checks in `references/cudy-wr3000s-ready-solution.md`.

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

If Telegram Web or WhatsApp Web works but the iPhone/Android app says there is no internet, do not only add domains. Check that direct Telegram/Meta CIDR routes exist on the router:

```sh
ip route | grep -E '91.108|91.105|149.154|185.76.151|95.161|31.13|57.141|129.134|157.240|185.60'
```

Re-run `scripts/install_openwrt_transparent_fakeip.sh` from the current GitHub version if these routes are missing.
