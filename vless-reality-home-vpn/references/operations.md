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

## Current Practical Default Domains

Use this as a practical starter set for macOS split routing:

```text
api.ipify.org
ipinfo.io
ifconfig.me
openai.com
chatgpt.com
oaistatic.com
oaiusercontent.com
openaiusercontent.com
facebook.com
messenger.com
instagram.com
www.instagram.com
cdninstagram.com
fbcdn.net
telegram.org
t.me
telegram.me
web.telegram.org
web.whatsapp.com
whatsapp.com
whatsapp.net
youtube.com
www.youtube.com
m.youtube.com
youtu.be
youtube-nocookie.com
googlevideo.com
ytimg.com
youtubei.googleapis.com
youtube.googleapis.com
ggpht.com
x.com
twitter.com
t.co
twimg.com
discord.com
discord.gg
discordcdn.com
signal.org
updates.signal.org
cdn.signal.org
linkedin.com
licdn.com
tiktok.com
tiktokcdn.com
byteoversea.com
patreon.com
soundcloud.com
sndcdn.com
speedtest.net
www.speedtest.net
speedtestcustom.com
ookla.com
ooklaserver.net
cdn.speedtest.net
install.speedtest.net
```
