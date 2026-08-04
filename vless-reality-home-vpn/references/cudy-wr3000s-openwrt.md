# Cudy WR3000S OpenWrt Router Plan

For the finished transparent VLESS router procedure, read `cudy-wr3000s-ready-solution.md`.

## Hardware And Firmware

Cudy WR3000S 1.0 is suitable for the router phase if it runs OpenWrt.

Confirmed practical baseline:

- model: Cudy WR3000S 1.0;
- CPU: 1.3 GHz dual-core ARM Cortex-A53;
- RAM: 256 MB;
- flash: 128 MB NAND;
- OpenWrt: use 24.10.5 or newer for newer WR3000S v1 variants.

Before flashing, check the exact hardware version and serial number on the label. Cudy notes that AX3000 series units manufactured from November 2025 can use new flash chips and must not be flashed with old intermediate or OpenWrt builds.

## Target Router Behavior

The router should become the only VPN client inside the home Wi-Fi network:

- selected domains go through VLESS Reality on the US VPS;
- everything else goes direct through the local ISP;
- devices inside the LAN should not need local Web Proxy, Secure Web Proxy, Streisand, or a local sing-box client while connected to this home Wi-Fi.

## Install Flow

1. Flash or verify OpenWrt on the router.
2. Enable SSH access to the router.
3. Copy `scripts/install_openwrt_router.sh` to the router.
4. Run it on the router as root with the private `vless://...` client link.
5. Disable device-level VPN/proxy clients on home Wi-Fi after router routing is verified.

Example:

```sh
scp vless-reality-home-vpn/scripts/install_openwrt_router.sh root@192.168.1.1:/tmp/
ssh root@192.168.1.1
sh /tmp/install_openwrt_router.sh 'vless://...'
```

## Verification

From any device connected to the router Wi-Fi:

```sh
curl https://api.ipify.org
```

Expected for routed test domains:

- `https://api.ipify.org` shows the VPS IP;
- `https://www.speedtest.net` opens through VLESS;
- ordinary non-listed domains should use the local ISP path.

On the router:

```sh
/etc/init.d/sing-box status
tail -n 80 /var/log/sing-box/sing-box.log
```

## Safer Automatic Client Mode

If TUN transparent routing breaks connectivity, keep `sing-box` in router proxy mode and publish a PAC file:

```sh
sh /tmp/install_openwrt_wpad.sh 192.168.1.1 7890
```

This exposes:

```text
http://192.168.1.1/wpad.dat
```

DHCP option 252 advertises the PAC file to LAN clients that support proxy auto-discovery. This is safer than TUN because it does not change the router default route.

## Transparent FakeIP Mode

For a true no-device-configuration setup, use transparent FakeIP mode after router proxy mode has been verified:

```sh
sh /tmp/install_openwrt_transparent_fakeip.sh
```

This mode keeps `192.168.1.1:7890` as a manual fallback proxy, sends only listed domains to sing-box DNS where they receive FakeIP addresses, and routes only `198.18.0.0/15` through the TUN interface. Ordinary domains stay on the normal ISP path.

Rollback:

```sh
sh /tmp/rollback_openwrt_transparent_fakeip.sh
```

## Rollback

Stop the router VPN:

```sh
/etc/init.d/sing-box stop
/etc/init.d/sing-box disable
```

Remove the router VPN files:

```sh
rm -f /etc/init.d/sing-box
rm -rf /etc/sing-box /var/log/sing-box
rm -f /usr/local/bin/sing-box
```

Then reboot the router.
