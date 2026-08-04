# Operations Reference

## Server Baseline

Target environment:

- Ubuntu 24.04 LTS VPS.
- Root or sudo SSH access.
- Public IPv4.
- `443/tcp` reachable from the client.

The server script installs:

- `sing-box` v1.13.16 to `/usr/local/bin/sing-box`;
- config at `/etc/sing-box/config.json`;
- systemd unit `sing-box.service`;
- log file `/var/log/sing-box/sing-box.log`;
- client share link at `/root/vless/client-link.txt`.

It also disables `xray` if present to avoid a port conflict on `443`.

## macOS Baseline

The client script installs:

- `~/.local/bin/sing-box`;
- config at `~/.config/sing-box/config.json`;
- PAC file at `~/.config/vless-home/proxy.pac`;
- LaunchAgent at `~/Library/LaunchAgents/com.codex.vless-sing-box.plist`;
- system HTTP and HTTPS proxy for the selected network service, default `Wi-Fi`;
- system Auto Proxy URL for the selected network service as a fallback hint.

The local mixed proxy listens on `127.0.0.1:7890`.

Keep HTTP and HTTPS proxy enabled for the active network service. PAC alone can be ignored by some applications, while the explicit proxy setting is more consistently honored.

## Validation Checklist

Run these checks after setup:

```bash
ssh root@SERVER_IP 'systemctl is-active sing-box && ss -ltnp | grep ":443 "'
curl -s https://api.ipify.org
curl -s -x http://127.0.0.1:7890 https://api.ipify.org
curl -s -x http://127.0.0.1:7890 https://ident.me
```

Expected:

- direct IP is the local network IP;
- proxied `api.ipify.org` is the VPS IP;
- proxied `ident.me` remains local unless it is in the PAC domain list.

## Known Good Reference

The reference RackNerd setup worked after switching the Reality handshake target from `www.microsoft.com` to `www.apple.com`.

Observed working split-routing result:

- direct: local ISP IP;
- `api.ipify.org` through local proxy: VPS IP;
- `ident.me` through local proxy: local ISP IP because it was not in the route list.
