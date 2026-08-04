#!/usr/bin/env sh
set -eu

latest_backup="$(ls -t /etc/sing-box/config.json.backup.* 2>/dev/null | head -n 1 || true)"

/etc/init.d/sing-box stop >/dev/null 2>&1 || true
/etc/init.d/sing-box disable >/dev/null 2>&1 || true

if [ -n "$latest_backup" ]; then
  cp "$latest_backup" /etc/sing-box/config.json
fi

uci -q delete dhcp.@dnsmasq[0].server
uci commit dhcp
/etc/init.d/dnsmasq restart

echo "Transparent FakeIP rollback applied."
if [ -n "$latest_backup" ]; then
  echo "Restored: $latest_backup"
fi
