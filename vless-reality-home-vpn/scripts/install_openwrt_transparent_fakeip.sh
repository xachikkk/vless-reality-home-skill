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
sing_box_bin="$(command -v sing-box)"

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

delete_firewall_sections() {
  while true; do
    idx="$(uci show firewall 2>/dev/null | sed -n "s/^firewall\\.@zone\\[\\([0-9][0-9]*\\)\\]\\.name='vless'$/\\1/p" | head -n 1)"
    [ -n "$idx" ] || break
    uci -q delete "firewall.@zone[$idx]" || break
  done
  while true; do
    idx="$(uci show firewall 2>/dev/null | sed -n "s/^firewall\\.@forwarding\\[\\([0-9][0-9]*\\)\\]\\.dest='vless'$/\\1/p" | head -n 1)"
    [ -n "$idx" ] || break
    uci -q delete "firewall.@forwarding[$idx]" || break
  done
  while true; do
    idx="$(uci show firewall 2>/dev/null | sed -n "s/^firewall\\.@rule\\[\\([0-9][0-9]*\\)\\]\\.name='Allow-LAN-to-VLESS-FakeIP'$/\\1/p" | head -n 1)"
    [ -n "$idx" ] || break
    uci -q delete "firewall.@rule[$idx]" || break
  done
}

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
      "auto_redirect": true,
      "strict_route": false,
      "route_address": [
        "198.18.0.0/15",
        "91.105.192.0/23",
        "91.108.4.0/22",
        "91.108.8.0/22",
        "91.108.12.0/22",
        "91.108.16.0/22",
        "91.108.20.0/22",
        "91.108.56.0/22",
        "149.154.160.0/20",
        "185.76.151.0/24",
        "95.161.64.0/20",
        "31.13.64.0/18",
        "45.64.40.0/22",
        "57.141.0.0/16",
        "66.220.144.0/20",
        "69.63.176.0/20",
        "69.171.224.0/19",
        "74.119.76.0/22",
        "102.132.96.0/20",
        "103.4.96.0/22",
        "129.134.0.0/16",
        "157.240.0.0/16",
        "173.252.64.0/18",
        "179.60.192.0/22",
        "185.60.216.0/22",
        "185.89.216.0/22",
        "204.15.20.0/22"
      ],
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
      {"domain_suffix": [
        "api.ipify.org", "ipinfo.io", "ifconfig.me",
        "openai.com", "chatgpt.com", "oaistatic.com", "oaiusercontent.com", "openaiusercontent.com",
        "meta.com", "oculus.com", "facebook.com", "messenger.com", "instagram.com", "cdninstagram.com", "fbcdn.net",
        "telegram.org", "t.me", "telegram.me", "web.telegram.org",
        "whatsapp.com", "whatsapp.net", "wa.me",
        "youtube.com", "youtu.be", "youtube-nocookie.com", "googlevideo.com", "ytimg.com", "youtubei.googleapis.com", "youtube.googleapis.com", "ggpht.com",
        "x.com", "twitter.com", "t.co", "twimg.com",
        "discord.com", "discord.gg", "discordcdn.com",
        "signal.org", "updates.signal.org", "cdn.signal.org",
        "linkedin.com", "licdn.com",
        "tiktok.com", "tiktokcdn.com", "byteoversea.com",
        "patreon.com", "soundcloud.com", "sndcdn.com",
        "speedtest.net", "speedtestcustom.com", "ookla.com", "ooklaserver.net",
        "github.com", "raw.githubusercontent.com", "objects.githubusercontent.com", "githubusercontent.com", "githubassets.com"
      ], "outbound": "usa-vless"},
      {"ip_cidr": [
        "91.105.192.0/23",
        "91.108.4.0/22",
        "91.108.8.0/22",
        "91.108.12.0/22",
        "91.108.16.0/22",
        "91.108.20.0/22",
        "91.108.56.0/22",
        "149.154.160.0/20",
        "185.76.151.0/24",
        "95.161.64.0/20",
        "31.13.64.0/18",
        "45.64.40.0/22",
        "57.141.0.0/16",
        "66.220.144.0/20",
        "69.63.176.0/20",
        "69.171.224.0/19",
        "74.119.76.0/22",
        "102.132.96.0/20",
        "103.4.96.0/22",
        "129.134.0.0/16",
        "157.240.0.0/16",
        "173.252.64.0/18",
        "179.60.192.0/22",
        "185.60.216.0/22",
        "185.89.216.0/22",
        "204.15.20.0/22"
      ], "outbound": "usa-vless"},
      {"ip_cidr": ["198.18.0.0/15"], "outbound": "usa-vless"}
    ],
    "final": "direct"
  }
}
EOF

sing-box check -c /etc/sing-box/config.json

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

uci -q delete dhcp.@dnsmasq[0].server || true
for domain in \
  api.ipify.org ipinfo.io ifconfig.me \
  openai.com chatgpt.com oaistatic.com oaiusercontent.com openaiusercontent.com \
  meta.com oculus.com facebook.com messenger.com instagram.com cdninstagram.com fbcdn.net \
  telegram.org t.me telegram.me web.telegram.org \
  whatsapp.com whatsapp.net wa.me \
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

delete_firewall_sections
uci -q delete firewall.vless || true
uci -q delete firewall.lan_to_vless || true
uci -q delete firewall.allow_lan_to_vless_fakeip || true
uci set firewall.vless='zone'
uci set firewall.vless.name='vless'
uci set firewall.vless.input='ACCEPT'
uci set firewall.vless.output='ACCEPT'
uci set firewall.vless.forward='ACCEPT'
uci add_list firewall.vless.device='vless-fakeip0'
uci set firewall.vless.masq='1'
uci set firewall.lan_to_vless='forwarding'
uci set firewall.lan_to_vless.src='lan'
uci set firewall.lan_to_vless.dest='vless'
uci set firewall.allow_lan_to_vless_fakeip='rule'
uci set firewall.allow_lan_to_vless_fakeip.name='Allow-LAN-to-VLESS-FakeIP'
uci set firewall.allow_lan_to_vless_fakeip.src='lan'
uci set firewall.allow_lan_to_vless_fakeip.dest_ip='198.18.0.0/15'
uci set firewall.allow_lan_to_vless_fakeip.proto='all'
uci set firewall.allow_lan_to_vless_fakeip.target='ACCEPT'
uci commit firewall

/etc/init.d/dnsmasq restart
/etc/init.d/firewall restart
/etc/init.d/sing-box enable
/etc/init.d/sing-box restart
sleep 2
ip route replace 198.18.0.0/15 dev vless-fakeip0 2>/dev/null || true
for cidr in \
  91.105.192.0/23 \
  91.108.4.0/22 \
  91.108.8.0/22 \
  91.108.12.0/22 \
  91.108.16.0/22 \
  91.108.20.0/22 \
  91.108.56.0/22 \
  149.154.160.0/20 \
  185.76.151.0/24 \
  95.161.64.0/20 \
  31.13.64.0/18 \
  45.64.40.0/22 \
  57.141.0.0/16 \
  66.220.144.0/20 \
  69.63.176.0/20 \
  69.171.224.0/19 \
  74.119.76.0/22 \
  102.132.96.0/20 \
  103.4.96.0/22 \
  129.134.0.0/16 \
  157.240.0.0/16 \
  173.252.64.0/18 \
  179.60.192.0/22 \
  185.60.216.0/22 \
  185.89.216.0/22 \
  204.15.20.0/22
do
  ip route replace "$cidr" dev vless-fakeip0 2>/dev/null || true
done

echo "Transparent FakeIP mode installed."
echo "Backup: ${backup}"
echo "Rollback: sh /tmp/rollback_openwrt_transparent_fakeip.sh"
