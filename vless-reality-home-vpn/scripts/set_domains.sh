#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: set_domains.sh domain1 domain2 ..." >&2
  exit 2
fi

config="$HOME/.config/sing-box/config.json"
pac="$HOME/.config/vless-home/proxy.pac"

python3 - "$config" "$pac" "$@" <<'PY'
import json
import sys
from pathlib import Path

config_path = Path(sys.argv[1])
pac_path = Path(sys.argv[2])
domains = [d.strip().lower() for d in sys.argv[3:] if d.strip()]

data = json.loads(config_path.read_text())
rules = data.setdefault("route", {}).setdefault("rules", [])
if not rules:
    rules.append({"domain_suffix": [], "outbound": "usa-vless"})
rules[0]["domain_suffix"] = domains
rules[0]["outbound"] = "usa-vless"
config_path.write_text(json.dumps(data, indent=2) + "\n")

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
pac_path.write_text(pac)
PY

"$HOME/.local/bin/sing-box" check -c "$config"
launchctl kickstart -k "gui/$(id -u)/com.codex.vless-sing-box" >/dev/null 2>&1 || true
echo "Updated domains: $*"
