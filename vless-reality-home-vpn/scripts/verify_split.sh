#!/usr/bin/env bash
set -euo pipefail

proxy="${PROXY:-http://127.0.0.1:7890}"
vpn_test="${VPN_TEST_URL:-https://api.ipify.org}"
direct_test="${DIRECT_TEST_URL:-https://ident.me}"

echo "direct ip:"
curl -sS --max-time 20 https://api.ipify.org || true
echo

echo "proxied routed-domain ip (${vpn_test}):"
curl -sS --max-time 30 -x "$proxy" "$vpn_test" || true
echo

echo "proxied non-routed-domain ip (${direct_test}):"
curl -sS --max-time 30 -x "$proxy" "$direct_test" || true
echo

echo "local listener:"
lsof -nP -iTCP:7890 -sTCP:LISTEN || true
