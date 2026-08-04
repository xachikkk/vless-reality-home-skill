#!/usr/bin/env sh
set -eu

usage() {
  cat <<'USAGE'
Usage:
  install_openwrt_router.sh 'vless://...'

Installs sing-box on an OpenWrt router and enables a LAN proxy listener.
Selected domains go through VLESS Reality, everything else goes direct for
clients that explicitly use the router proxy.

Run this script on the router as root.
USAGE
}

link="${1:-}"
if [ -n "$link" ]; then
  shift || true
fi

while [ "$#" -gt 0 ]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 2
      ;;
  esac
done

if [ -z "$link" ]; then
  usage
  exit 2
fi

if [ "$(id -u)" != "0" ]; then
  echo "Run as root on OpenWrt." >&2
  exit 1
fi

opkg update
if ! command -v python3 >/dev/null 2>&1 || ! python3 - <<'PY' >/dev/null 2>&1
from urllib.parse import urlparse
PY
then
  opkg install python3-light python3-urllib
fi

opkg install ca-bundle kmod-inet-diag

if ! command -v sing-box >/dev/null 2>&1; then
  opkg install sing-box-tiny
fi

sing_box_bin="$(command -v sing-box)"
mkdir -p /etc/sing-box /var/log/sing-box

python3 - "$link" /etc/sing-box/config.json <<'PY'
import json
import sys
from pathlib import Path
from urllib.parse import parse_qs, urlparse

link, config_path = sys.argv[1:3]
u = urlparse(link)
if u.scheme != "vless":
    raise SystemExit("Expected a vless:// link")

uuid = u.username
server = u.hostname
port = u.port or 443
q = parse_qs(u.query)
public_key = q.get("pbk", [""])[0]
sni = q.get("sni", ["www.apple.com"])[0]
short_id = q.get("sid", [""])[0]
flow = q.get("flow", ["xtls-rprx-vision"])[0]

domains = [
    "api.ipify.org",
    "ipinfo.io",
    "ifconfig.me",
    "openai.com",
    "chatgpt.com",
    "oaistatic.com",
    "oaiusercontent.com",
    "openaiusercontent.com",
    "meta.com",
    "www.meta.com",
    "oculus.com",
    "www.oculus.com",
    "facebook.com",
    "messenger.com",
    "instagram.com",
    "www.instagram.com",
    "cdninstagram.com",
    "fbcdn.net",
    "telegram.org",
    "t.me",
    "telegram.me",
    "web.telegram.org",
    "web.whatsapp.com",
    "whatsapp.com",
    "whatsapp.net",
    "youtube.com",
    "www.youtube.com",
    "m.youtube.com",
    "youtu.be",
    "youtube-nocookie.com",
    "googlevideo.com",
    "ytimg.com",
    "youtubei.googleapis.com",
    "youtube.googleapis.com",
    "ggpht.com",
    "x.com",
    "twitter.com",
    "t.co",
    "twimg.com",
    "discord.com",
    "discord.gg",
    "discordcdn.com",
    "signal.org",
    "updates.signal.org",
    "cdn.signal.org",
    "linkedin.com",
    "licdn.com",
    "tiktok.com",
    "tiktokcdn.com",
    "byteoversea.com",
    "patreon.com",
    "soundcloud.com",
    "sndcdn.com",
    "speedtest.net",
    "www.speedtest.net",
    "speedtestcustom.com",
    "ookla.com",
    "ooklaserver.net",
    "cdn.speedtest.net",
    "install.speedtest.net",
    "github.com",
    "www.github.com",
    "api.github.com",
    "raw.githubusercontent.com",
    "objects.githubusercontent.com",
    "githubusercontent.com",
    "githubassets.com",
]

config = {
    "log": {
        "level": "info",
        "output": "/var/log/sing-box/sing-box.log",
        "timestamp": True,
    },
    "dns": {
        "servers": [
            {"tag": "local", "address": "local"},
            {"tag": "remote", "address": "https://1.1.1.1/dns-query", "detour": "usa-vless"},
        ],
        "rules": [
            {"domain_suffix": domains, "server": "remote"},
        ],
        "final": "local",
        "strategy": "ipv4_only",
    },
    "inbounds": [
        {
            "type": "mixed",
            "tag": "lan-proxy",
            "listen": "0.0.0.0",
            "listen_port": 7890,
        }
    ],
    "outbounds": [
        {"type": "direct", "tag": "direct"},
        {
            "type": "vless",
            "tag": "usa-vless",
            "server": server,
            "server_port": port,
            "uuid": uuid,
            "flow": flow,
            "tls": {
                "enabled": True,
                "server_name": sni,
                "utls": {"enabled": True, "fingerprint": "chrome"},
                "reality": {
                    "enabled": True,
                    "public_key": public_key,
                    "short_id": short_id,
                },
            },
        },
        {"type": "block", "tag": "block"},
    ],
    "route": {
        "auto_detect_interface": True,
        "rules": [
            {"domain_suffix": domains, "outbound": "usa-vless"},
        ],
        "final": "direct",
    },
}

Path(config_path).write_text(json.dumps(config, indent=2) + "\n")
print(f"server={server}")
print(f"sni={sni}")
print(f"domains={len(domains)}")
PY

chmod 600 /etc/sing-box/config.json
"$sing_box_bin" check -c /etc/sing-box/config.json

cat > /etc/init.d/sing-box <<EOF
#!/bin/sh /etc/rc.common

START=99
STOP=10
USE_PROCD=1

start_service() {
  mkdir -p /var/log/sing-box
  procd_open_instance
  procd_set_param command ${sing_box_bin} run -c /etc/sing-box/config.json
  procd_set_param respawn 3600 5 5
  procd_set_param stdout 1
  procd_set_param stderr 1
  procd_close_instance
}
EOF

chmod +x /etc/init.d/sing-box

echo "sing-box router proxy mode is installed."
echo "Start with: /etc/init.d/sing-box start"
echo "Log: tail -f /var/log/sing-box/sing-box.log"
