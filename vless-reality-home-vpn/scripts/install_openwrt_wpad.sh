#!/usr/bin/env sh
set -eu

router_ip="${1:-192.168.1.1}"
proxy_port="${2:-7890}"

if [ "$(id -u)" != "0" ]; then
  echo "Run as root on OpenWrt." >&2
  exit 1
fi

mkdir -p /www

cat > /www/wpad.dat <<EOF
function FindProxyForURL(url, host) {
  host = host.toLowerCase();
  var vpnDomains = [
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
    "githubassets.com"
  ];
  for (var i = 0; i < vpnDomains.length; i++) {
    var d = vpnDomains[i];
    if (host === d || dnsDomainIs(host, "." + d)) {
      return "PROXY ${router_ip}:${proxy_port}; DIRECT";
    }
  }
  return "DIRECT";
}
EOF

uci -q delete dhcp.lan.dhcp_option || true
uci add_list dhcp.lan.dhcp_option="252,http://${router_ip}/wpad.dat"
uci -q delete dhcp.@dnsmasq[0].address || true
uci add_list dhcp.@dnsmasq[0].address="/wpad/${router_ip}"
uci commit dhcp
/etc/init.d/dnsmasq restart
/etc/init.d/uhttpd restart

echo "PAC URL: http://${router_ip}/wpad.dat"
echo "DHCP option 252 is enabled for LAN."
