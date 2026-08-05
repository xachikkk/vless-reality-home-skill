# VLESS Reality Home VPN Skill

Codex skill for quickly deploying a VLESS + Reality VPN on a low-cost Ubuntu VPS and configuring macOS split-routing through sing-box.

The skill lives in:

```text
vless-reality-home-vpn/
```

Install the skill by copying that folder into:

```text
~/.codex/skills/
```

Typical use:

```bash
vless-reality-home-vpn/scripts/install_server.sh root@SERVER_IP
vless-reality-home-vpn/scripts/install_macos_client.sh 'vless://...'
vless-reality-home-vpn/scripts/set_domains.sh api.ipify.org ipinfo.io ifconfig.me openai.com chatgpt.com oaistatic.com oaiusercontent.com openaiusercontent.com telegram.org t.me telegram.me web.telegram.org youtube.com youtu.be googlevideo.com ytimg.com instagram.com cdninstagram.com speedtest.net ookla.com ooklaserver.net
vless-reality-home-vpn/scripts/verify_split.sh
```

Router phase for OpenWrt, including Cudy WR3000S proxy mode:

```sh
scp vless-reality-home-vpn/scripts/install_openwrt_router.sh root@192.168.1.1:/tmp/
ssh root@192.168.1.1
sh /tmp/install_openwrt_router.sh 'vless://...'
```

Transparent no-device-configuration mode for Cudy WR3000S:

```sh
wget -O /tmp/install_openwrt_transparent_fakeip.sh "https://raw.githubusercontent.com/xachikkk/vless-reality-home-skill/main/vless-reality-home-vpn/scripts/install_openwrt_transparent_fakeip.sh?$(date +%s)"
chmod +x /tmp/install_openwrt_transparent_fakeip.sh
sh /tmp/install_openwrt_transparent_fakeip.sh
```

Safer automatic LAN proxy discovery:

```sh
scp vless-reality-home-vpn/scripts/install_openwrt_wpad.sh root@192.168.1.1:/tmp/
ssh root@192.168.1.1
sh /tmp/install_openwrt_wpad.sh 192.168.1.1 7890
```

Read `vless-reality-home-vpn/references/cudy-wr3000s-ready-solution.md` before changing a live Cudy WR3000S router.
Read `vless-reality-home-vpn/references/cudy-wr3000s-openwrt.md` before flashing OpenWrt.

Mobile app note:

- Telegram and WhatsApp mobile apps may connect directly to Telegram/Meta IP ranges, so transparent router mode includes CIDR routes in addition to domain/FakeIP rules.

Security notes:

- Use SSH keys.
- Do not paste permanent passwords into chats.
- Rotate any password that was disclosed.
- Keep the VLESS link private.
