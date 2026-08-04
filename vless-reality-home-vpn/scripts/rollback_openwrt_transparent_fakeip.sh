#!/usr/bin/env sh
set -eu

latest_backup="$(ls -t /etc/sing-box/config.json.backup.* 2>/dev/null | head -n 1 || true)"

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

/etc/init.d/sing-box stop >/dev/null 2>&1 || true
/etc/init.d/sing-box disable >/dev/null 2>&1 || true

if [ -n "$latest_backup" ]; then
  cp "$latest_backup" /etc/sing-box/config.json
fi

uci -q delete dhcp.@dnsmasq[0].server || true
uci commit dhcp

delete_firewall_sections
uci -q delete firewall.vless || true
uci -q delete firewall.lan_to_vless || true
uci -q delete firewall.allow_lan_to_vless_fakeip || true
uci commit firewall

ip route del 198.18.0.0/15 dev vless-fakeip0 2>/dev/null || true

/etc/init.d/dnsmasq restart
/etc/init.d/firewall restart

echo "Transparent FakeIP rollback applied."
if [ -n "$latest_backup" ]; then
  echo "Restored: $latest_backup"
fi
