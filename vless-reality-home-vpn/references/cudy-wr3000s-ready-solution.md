# Cudy WR3000S VLESS Reality Router Ready Solution

## Purpose

This is the proven setup for Cudy WR3000S V1.0 running OpenWrt 24.10.6.

Target behavior:

- every LAN port and both Wi-Fi networks are in the `lan` zone;
- selected domains use the US VLESS Reality VPS through sing-box;
- all other domains go directly through the local ISP;
- client devices do not need local VPN, proxy, PAC, Streisand, or sing-box while connected to this router;
- manual proxy `192.168.1.1:7890` remains available only as a fallback test path.

Do not store the real `vless://...` link in GitHub, documentation, screenshots, or generated artifacts.

## Known Good Baseline

- router: Cudy WR3000S V1.0;
- firmware: OpenWrt 24.10.6;
- sing-box package: `sing-box-tiny` 1.12.22 on `aarch64_cortex-a53`;
- LAN router IP: `192.168.1.1`;
- transparent interface: `vless-fakeip0`;
- FakeIP range: `198.18.0.0/15`;
- router proxy fallback: `0.0.0.0:7890`;
- sing-box DNS listener: `127.0.0.1:5353`.

## Safety Rules

- Warn the user before any command that restarts Wi-Fi or networking.
- Do not run `wifi down` over a Wi-Fi SSH session.
- Prefer Ethernet, LuCI, `wifi reload`, or a planned reboot for wireless changes.
- Keep rollback command ready:

```sh
sh /tmp/rollback_openwrt_transparent_fakeip.sh
```

## Install Sequence

Flash OpenWrt first and verify that the router has internet and Wi-Fi.

Download the scripts on the router:

```sh
cd /tmp
wget -O /tmp/install_openwrt_router.sh "https://raw.githubusercontent.com/xachikkk/vless-reality-home-skill/main/vless-reality-home-vpn/scripts/install_openwrt_router.sh?$(date +%s)"
wget -O /tmp/install_openwrt_transparent_fakeip.sh "https://raw.githubusercontent.com/xachikkk/vless-reality-home-skill/main/vless-reality-home-vpn/scripts/install_openwrt_transparent_fakeip.sh?$(date +%s)"
wget -O /tmp/rollback_openwrt_transparent_fakeip.sh "https://raw.githubusercontent.com/xachikkk/vless-reality-home-skill/main/vless-reality-home-vpn/scripts/rollback_openwrt_transparent_fakeip.sh?$(date +%s)"
chmod +x /tmp/install_openwrt_router.sh /tmp/install_openwrt_transparent_fakeip.sh /tmp/rollback_openwrt_transparent_fakeip.sh
```

Install router proxy mode first, using the private VLESS link:

```sh
sh /tmp/install_openwrt_router.sh 'vless://PASTE_PRIVATE_LINK_HERE'
```

Verify proxy mode from a LAN/Wi-Fi client:

```sh
/usr/bin/curl -x http://192.168.1.1:7890 https://api.ipify.org
```

Expected: VPS IP.

Enable transparent FakeIP mode:

```sh
sh /tmp/install_openwrt_transparent_fakeip.sh
```

## Wi-Fi Binding

Both SSIDs must be attached to `lan`.

Check:

```sh
uci show wireless | grep -E "ssid|network"
```

Expected pattern:

```text
wireless.default_radio1.network='lan'
wireless.default_radio1.ssid='FBI15'
wireless.wifinet2.ssid='FBI1'
wireless.wifinet2.network='lan'
```

If an SSID shows `wan wan6`, change it carefully. This can interrupt Wi-Fi; prefer Ethernet or LuCI.

```sh
uci set wireless.wifinet2.network='lan'
uci set wireless.default_radio1.network='lan'
uci commit wireless
wifi reload
```

## Router Verification

On the router:

```sh
/etc/init.d/sing-box status
ls -l /etc/rc.d/*sing-box*
netstat -lntup | grep -E '5353|7890'
ip route | grep 198.18
uci show firewall | grep -E 'vless|FakeIP|forwarding'
```

Expected:

- `sing-box` is `running`;
- `/etc/rc.d/S99sing-box` exists;
- `127.0.0.1:5353` is listening;
- `0.0.0.0:7890` is listening;
- route `198.18.0.0/15 dev vless-fakeip0` exists;
- firewall has `vless`, `lan_to_vless`, and `Allow-LAN-to-VLESS-FakeIP`.

## Client Verification

On macOS connected to any router Wi-Fi or LAN port, with system proxy disabled:

```sh
/usr/sbin/networksetup -setwebproxystate "Wi-Fi" off
/usr/sbin/networksetup -setsecurewebproxystate "Wi-Fi" off
/usr/bin/dscacheutil -flushcache
/usr/bin/dig @192.168.1.1 api.ipify.org
/usr/bin/curl https://api.ipify.org
```

Expected:

- `dig` returns `198.18.x.x`;
- `curl` returns the VPS IP.

For non-macOS devices, open `https://api.ipify.org` or use any local curl-capable terminal. The returned IP should be the VPS IP for this test domain.

## Reboot Test

After installation, reboot once:

```sh
reboot
```

Wait 1-2 minutes, then verify again:

```sh
/etc/init.d/sing-box status
netstat -lntup | grep -E '5353|7890'
```

The init script must create `/var/log/sing-box` during `start_service()`, because `/var/log` is temporary on OpenWrt. If this directory is not created at start, sing-box can fail after reboot with:

```text
FATAL start logger: open /var/log/sing-box/sing-box.log: no such file or directory
```

## Troubleshooting

DNS timeout for listed domains:

```sh
/etc/init.d/sing-box status
netstat -lntup | grep -E ':53|5353|7890'
logread | tail -n 120
sing-box check -c /etc/sing-box/config.json
```

FakeIP resolves but connection times out:

```sh
ip route | grep 198.18
ip route get 198.18.0.3
tail -n 120 /var/log/sing-box/sing-box.log
```

One Wi-Fi band works and the other does not:

```sh
uci show wireless | grep -E "ssid|network"
```

Both should be `network='lan'`.

## Rollback

```sh
sh /tmp/rollback_openwrt_transparent_fakeip.sh
reboot
```

Rollback restores the last `/etc/sing-box/config.json.backup.*`, removes FakeIP DHCP forwarding rules and VLESS firewall rules, stops and disables sing-box, and restarts dnsmasq/firewall.
