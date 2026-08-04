#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  install_server.sh root@SERVER_IP [--sni www.apple.com] [--port 443] [--version 1.13.16]

Installs sing-box VLESS Reality on an Ubuntu VPS and prints a VLESS client link.
Use SSH key access. Do not pass passwords in shell history.
USAGE
}

target="${1:-}"
shift || true
sni="www.apple.com"
port="443"
version="1.13.16"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --sni) sni="${2:?missing --sni value}"; shift 2 ;;
    --port) port="${2:?missing --port value}"; shift 2 ;;
    --version) version="${2:?missing --version value}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 2 ;;
  esac
done

if [[ -z "$target" ]]; then
  usage
  exit 2
fi

ssh "$target" "SNI='$sni' PORT='$port' SING_BOX_VERSION='$version' bash -s" <<'REMOTE'
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y curl jq openssl tar gzip ca-certificates ufw

arch="$(uname -m)"
case "$arch" in
  x86_64|amd64) asset_arch="amd64" ;;
  aarch64|arm64) asset_arch="arm64" ;;
  *) echo "Unsupported architecture: $arch" >&2; exit 1 ;;
esac

tmp="$(mktemp -d)"
url="https://github.com/SagerNet/sing-box/releases/download/v${SING_BOX_VERSION}/sing-box-${SING_BOX_VERSION}-linux-${asset_arch}.tar.gz"
curl -L --fail --connect-timeout 20 --max-time 180 -o "$tmp/sing-box.tgz" "$url"
tar -xzf "$tmp/sing-box.tgz" -C "$tmp"
bin="$(find "$tmp" -type f -name sing-box | head -n 1)"
install -m 755 "$bin" /usr/local/bin/sing-box

uuid="$(/usr/local/bin/sing-box generate uuid 2>/dev/null || cat /proc/sys/kernel/random/uuid)"
keys="$(/usr/local/bin/sing-box generate reality-keypair)"
private_key="$(printf '%s\n' "$keys" | sed -n 's/^PrivateKey: //p')"
public_key="$(printf '%s\n' "$keys" | sed -n 's/^PublicKey: //p')"
short_id="$(openssl rand -hex 4)"

mkdir -p /etc/sing-box /var/log/sing-box /root/vless
cat > /etc/sing-box/config.json <<EOF
{
  "log": {
    "level": "info",
    "output": "/var/log/sing-box/sing-box.log",
    "timestamp": true
  },
  "inbounds": [
    {
      "type": "vless",
      "tag": "vless-in",
      "listen": "::",
      "listen_port": ${PORT},
      "users": [
        {
          "name": "home-client",
          "uuid": "${uuid}",
          "flow": "xtls-rprx-vision"
        }
      ],
      "tls": {
        "enabled": true,
        "server_name": "${SNI}",
        "reality": {
          "enabled": true,
          "handshake": {
            "server": "${SNI}",
            "server_port": 443
          },
          "private_key": "${private_key}",
          "short_id": ["${short_id}"]
        }
      }
    }
  ],
  "outbounds": [
    {"type": "direct", "tag": "direct"},
    {"type": "block", "tag": "block"}
  ]
}
EOF
chmod 600 /etc/sing-box/config.json
/usr/local/bin/sing-box check -c /etc/sing-box/config.json

cat > /etc/systemd/system/sing-box.service <<'EOF'
[Unit]
Description=sing-box service
After=network.target nss-lookup.target

[Service]
User=root
ExecStart=/usr/local/bin/sing-box run -c /etc/sing-box/config.json
Restart=on-failure
RestartSec=5s
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl disable --now xray >/dev/null 2>&1 || true
systemctl enable --now sing-box
ufw allow OpenSSH >/dev/null
ufw allow "${PORT}/tcp" >/dev/null
ufw --force enable >/dev/null

public_ip="$(curl -4 -s https://api.ipify.org || true)"
link="vless://${uuid}@${public_ip}:${PORT}?type=tcp&security=reality&pbk=${public_key}&fp=chrome&sni=${SNI}&sid=${short_id}&flow=xtls-rprx-vision#VLESS-Reality-Home"
printf '%s\n' "$link" > /root/vless/client-link.txt

echo "sing-box: $(systemctl is-active sing-box)"
echo "client-link: $link"
REMOTE
