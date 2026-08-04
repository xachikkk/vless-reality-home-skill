# Common Blocked Or Restricted Services

This reference is a practical routing aid, not a legal registry. Status changes by provider, region, ISP, app version, and Roskomnadzor enforcement method. Add domains service by service and verify.

## Already Added Starter Set

OpenAI / ChatGPT:

```text
openai.com
chatgpt.com
oaistatic.com
oaiusercontent.com
openaiusercontent.com
```

Telegram web and links:

```text
telegram.org
t.me
telegram.me
web.telegram.org
```

YouTube:

```text
youtube.com
www.youtube.com
m.youtube.com
youtu.be
youtube-nocookie.com
googlevideo.com
ytimg.com
youtubei.googleapis.com
youtube.googleapis.com
ggpht.com
```

Instagram:

```text
instagram.com
www.instagram.com
cdninstagram.com
fbcdn.net
```

Speedtest / Ookla for VLESS speed checks:

```text
speedtest.net
www.speedtest.net
speedtestcustom.com
ookla.com
ooklaserver.net
cdn.speedtest.net
install.speedtest.net
```

## Candidates To Discuss Before Adding

Facebook / Meta:

```text
facebook.com
www.facebook.com
fb.com
messenger.com
facebook.net
fbcdn.net
```

WhatsApp:

```text
whatsapp.com
web.whatsapp.com
whatsapp.net
static.whatsapp.net
```

X / Twitter:

```text
x.com
twitter.com
t.co
twimg.com
```

Discord:

```text
discord.com
discord.gg
discordapp.com
discordapp.net
discordcdn.com
```

Signal:

```text
signal.org
updates.signal.org
storage.signal.org
cdn.signal.org
```

Viber:

```text
viber.com
account.viber.com
download.cdn.viber.com
```

LinkedIn:

```text
linkedin.com
www.linkedin.com
licdn.com
```

TikTok:

```text
tiktok.com
www.tiktok.com
tiktokcdn.com
tiktokv.com
byteoversea.com
ibytedtos.com
```

Patreon:

```text
patreon.com
www.patreon.com
patreonusercontent.com
```

SoundCloud:

```text
soundcloud.com
sndcdn.com
```

## Notes

- Desktop Telegram may need its own proxy settings or TUN/router mode; domain routing mainly helps web.telegram.org and browser links.
- YouTube uses many CDN hostnames under `googlevideo.com`; include that domain for playback.
- Instagram uses Meta CDNs; `cdninstagram.com` and `fbcdn.net` are usually required for media.
- Avoid adding broad domains such as `google.com`, `googleapis.com`, or `facebook.net` unless the user accepts routing more traffic through the VPS.
