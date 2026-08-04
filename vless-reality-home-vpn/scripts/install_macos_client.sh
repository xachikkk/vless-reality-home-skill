#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  install_macos_client.sh 'vless://...' [--service Wi-Fi] [--version 1.13.16]

Installs a local sing-box proxy on macOS, starts it with LaunchAgent,
and enables a PAC file for per-domain split routing.
USAGE
}

link="${1:-}"
shift || true
service="Wi-Fi"
version="1.13.16"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --service) service="${2:?missing --service value}"; shift 2 ;;
    --version) version="${2:?missing --version value}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 2 ;;
  esac
done

if [[ -z "$link" ]]; then
  usage
  exit 2
fi

mkdir -p "$HOME/.local/bin" "$HOME/.config/sing-box" "$HOME/.config/vless-home" "$HOME/Library/LaunchAgents"

arch="$(uname -m)"
case "$arch" in
  arm64) asset_arch="arm64" ;;
  x86_64) asset_arch="amd64" ;;
  *) echo "Unsupported architecture: $arch" >&2; exit 1 ;;
esac

tmp="$(mktemp -d)"
url="https://github.com/SagerNet/sing-box/releases/download/v${version}/sing-box-${version}-darwin-${asset_arch}.tar.gz"
curl -L --fail --connect-timeout 20 --max-time 180 -o "$tmp/sing-box.tgz" "$url"
tar -xzf "$tmp/sing-box.tgz" -C "$tmp"
bin="$(find "$tmp" -type f -name sing-box | head -n 1)"
cp "$bin" "$HOME/.local/bin/sing-box"
chmod +x "$HOME/.local/bin/sing-box"

python3 - "$link" "$HOME/.config/sing-box/config.json" "$HOME/.config/vless-home/proxy.pac" <<'PY'
import json
import sys
from pathlib import Path
from urllib.parse import parse_qs, unquote, urlparse

link, config_path, pac_path = sys.argv[1:4]
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
]

config = {
    "log": {"level": "info"},
    "inbounds": [{
        "type": "mixed",
        "tag": "local-proxy",
        "listen": "127.0.0.1",
        "listen_port": 7890,
    }],
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
        "rules": [{"domain_suffix": domains, "outbound": "usa-vless"}],
        "final": "direct",
    },
}
Path(config_path).write_text(json.dumps(config, indent=2) + "\n")

domain_lines = ",\n    ".join(json.dumps(d) for d in domains)
pac = f'''function FindProxyForURL(url, host) {{
  host = host.toLowerCase();
  var vpnDomains = [
    {domain_lines}
  ];
  for (var i = 0; i < vpnDomains.length; i++) {{
    var d = vpnDomains[i];
    if (host === d || dnsDomainIs(host, "." + d)) {{
      return "PROXY 127.0.0.1:7890; DIRECT";
    }}
  }}
  return "DIRECT";
}}
'''
Path(pac_path).write_text(pac)
print(f"server={server}")
print(f"sni={sni}")
PY

chmod 600 "$HOME/.config/sing-box/config.json"
"$HOME/.local/bin/sing-box" check -c "$HOME/.config/sing-box/config.json"

cat > "$HOME/Library/LaunchAgents/com.codex.vless-sing-box.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.codex.vless-sing-box</string>
  <key>ProgramArguments</key>
  <array>
    <string>${HOME}/.local/bin/sing-box</string>
    <string>run</string>
    <string>-c</string>
    <string>${HOME}/.config/sing-box/config.json</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>StandardOutPath</key>
  <string>${HOME}/.config/vless-home/sing-box.out.log</string>
  <key>StandardErrorPath</key>
  <string>${HOME}/.config/vless-home/sing-box.err.log</string>
</dict>
</plist>
EOF

plutil -lint "$HOME/Library/LaunchAgents/com.codex.vless-sing-box.plist"
launchctl bootout "gui/$(id -u)" "$HOME/Library/LaunchAgents/com.codex.vless-sing-box.plist" >/dev/null 2>&1 || true
launchctl bootstrap "gui/$(id -u)" "$HOME/Library/LaunchAgents/com.codex.vless-sing-box.plist"
launchctl enable "gui/$(id -u)/com.codex.vless-sing-box"
launchctl kickstart -k "gui/$(id -u)/com.codex.vless-sing-box"

pac_url="file://${HOME}/.config/vless-home/proxy.pac"
networksetup -setautoproxyurl "$service" "$pac_url"
networksetup -setautoproxystate "$service" on
networksetup -setwebproxy "$service" 127.0.0.1 7890 off
networksetup -setsecurewebproxy "$service" 127.0.0.1 7890 off
networksetup -setwebproxystate "$service" on
networksetup -setsecurewebproxystate "$service" on

echo "LaunchAgent: com.codex.vless-sing-box"
networksetup -getautoproxyurl "$service"
networksetup -getwebproxy "$service"
networksetup -getsecurewebproxy "$service"
