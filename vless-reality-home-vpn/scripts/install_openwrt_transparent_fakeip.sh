#!/usr/bin/env sh
set -eu

if [ "$(id -u)" != "0" ]; then
  echo "Run as root on OpenWrt." >&2
  exit 1
fi

if [ ! -s /etc/sing-box/config.json ]; then
  echo "/etc/sing-box/config.json is missing. Run install_openwrt_router.sh first." >&2
  exit 1
fi

if ! command -v sing-box >/dev/null 2>&1; then
  echo "sing-box is missing. Install sing-box-tiny first." >&2
  exit 1
fi

if ! command -v jsonfilter >/dev/null 2>&1; then
  opkg update
  opkg install jsonfilter
fi

server="$(jsonfilter -i /etc/sing-box/config.json -e '@.outbounds[1].server')"
port="$(jsonfilter -i /etc/sing-box/config.json -e '@.outbounds[1].server_port')"
uuid="$(jsonfilter -i /etc/sing-box/config.json -e '@.outbounds[1].uuid')"
flow="$(jsonfilter -i /etc/sing-box/config.json -e '@.outbounds[1].flow')"
sni="$(jsonfilter -i /etc/sing-box/config.json -e '@.outbounds[1].tls.server_name')"
public_key="$(jsonfilter -i /etc/sing-box/config.json -e '@.outbounds[1].tls.reality.public_key')"
short_id="$(jsonfilter -i /etc/sing-box/config.json -e '@.outbounds[1].tls.reality.short_id')"

if [ -z "$server" ] || [ -z "$uuid" ] || [ -z "$public_key" ]; then
  echo "Could not read VLESS outbound from /etc/sing-box/config.json." >&2
  exit 1
fi

port="${port:-443}"
flow="${flow:-xtls-rprx-vision}"
sni="${sni:-www.apple.com}"

backup="/etc/sing-box/config.json.backup.$(date +%Y%m%d%H%M%S)"
cp /etc/sing-box/config.json "$backup"
mkdir -p /var/log/sing-box

cat > /etc/sing-box/config.json <<EOF
{
  "log": {"level": "info", "output": "/var/log/sing-box/sing-box.log", "timestamp": true},
  "dns": {
    "servers": [
      {"tag": "local", "address": "local"},
      {"tag": "remote", "address": "https://1.1.1.1/dns-query", "detour": "usa-vless"},
      {"tag": "fakeip", "address": "fakeip"}
    ],
    "rules": [
      {"domain_suffix": [
        "api.ipify.org", "ipinfo.io", "ifconfig.me",
        "openai.com", "chatgpt.com", "oaistatic.com", "oaiusercontent.com", "openaiusercontent.com",
        "meta.com", "oculus.com", "facebook.com", "messenger.com", "instagram.com", "cdninstagram.com", "fbcdn.net",
        "telegram.org", "t.me", "telegram.me", "web.telegram.org",
        "whatsapp.com", "whatsapp.net",
        "youtube.com", "youtu.be", "youtube-nocookie.com", "googlevideo.com", "ytimg.com", "youtubei.googleapis.com", "youtube.googleapis.com", "ggpht.com",
        "x.com", "twitter.com", "t.co", "twimg.com",
        "discord.com", "discord.gg", "discordcdn.com",
        "signal.org", "updates.signal.org", "cdn.signal.org",
        "linkedin.com", "licdn.com",
        "tiktok.com", "tiktokcdn.com", "byteoversea.com",
        "patreon.com", "soundcloud.com", "sndcdn.com",
        "speedtest.net", "speedtestcustom.com", "ookla.com", "ooklaserver.net",
        "github.com", "raw.githubusercontent.com", "objects.githubusercontent.com", "githubusercontent.com", "githubassets.com"
      ], "server": "fakeip"}
    ],
    "final": "local",
    "strategy": "ipv4_only",
    "fakeip": {"enabled": true, "inet4_range": "198.18.0.0/15"}
  },
  "inbounds": [
    {"type": "mixed", "tag": "lan-proxy", "listen": "0.0.0.0", "listen_port": 7890},
    {"type": "direct", "tag": "dns-in", "listen": "127.0.0.1", "listen_port": 5353, "network": "udp"},
    {
      "type": "tun",
      "tag": "fakeip-tun",
      "interface_name": "vless-fakeip0",
      "address": ["172.19.0.1/30"],
      "mtu": 9000,
      "auto_route": true,
      "strict_route": false,
      "route_address": ["198.18.0.0/15"],
      "stack": "system"
    }
  ],
  "outbounds": [
    {"type": "direct", "tag": "direct"},
    {
      "type": "vless",
      "tag": "usa-vless",
      "server": "${server}",
      "server_port": ${port},
      "uuid": "${uuid}",
      "flow": "${flow}",
      "tls": {
        "enabled": true,
        "server_name": "${sni}",
        "utls": {"enabled": true, "fingerprint": "chrome"},
        "reality": {"enabled": true, "public_key": "${public_key}", "short_id": "${short_id}"}
      }
    },
    {"type": "block", "tag": "block"}
  ],
  "route": {
    "auto_detect_interface": true,
    "rules": [
      {"inbound": "dns-in", "action": "hijack-dns"},
      {"ip_cidr": ["198.18.0.0/15"], "outbound": "usa-vless"}
    ],
    "final": "direct"
  }
}
EOF

sing-box check -c /etc/sing-box/config.json

uci -q delete dhcp.@dnsmasq[0].server || true
for domain in \
  api.ipify.org ipinfo.io ifconfig.me \
  openai.com chatgpt.com oaistatic.com oaiusercontent.com openaiusercontent.com \
  meta.com oculus.com facebook.com messenger.com instagram.com cdninstagram.com fbcdn.net \
  telegram.org t.me telegram.me web.telegram.org \
  whatsapp.com whatsapp.net \
  youtube.com youtu.be youtube-nocookie.com googlevideo.com ytimg.com youtubei.googleapis.com youtube.googleapis.com ggpht.com \
  x.com twitter.com t.co twimg.com \
  discord.com discord.gg discordcdn.com \
  signal.org updates.signal.org cdn.signal.org \
  linkedin.com licdn.com \
  tiktok.com tiktokcdn.com byteoversea.com \
  patreon.com soundcloud.com sndcdn.com \
  speedtest.net speedtestcustom.com ookla.com ooklaserver.net \
  github.com raw.githubusercontent.com objects.githubusercontent.com githubusercontent.com githubassets.com
do
  uci add_list dhcp.@dnsmasq[0].server="/${domain}/127.0.0.1#5353"
done
uci commit dhcp

/etc/init.d/dnsmasq restart
/etc/init.d/sing-box restart

echo "Transparent FakeIP mode installed."
echo "Backup: ${backup}"
echo "Rollback: sh /tmp/rollback_openwrt_transparent_fakeip.sh"
