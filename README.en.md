[中文](README.md) | **English** | [日本語](README.ja.md) | [한국어](README.ko.md)

# FreeBox — One free VPS, a whole self-hosted base

I got tired of the gap between "I snatched a free ARM machine" and "it actually does useful work". Every tutorial stops at a blank Ubuntu. FreeBox is the setup I install after grabbing a machine — the exact system that has been running on my own free box for months, packed into one command:

- **AdGuard Home**: filtering DNS that blocks ads and trackers for your whole network
- **SubHub**: generates proxy subscription links from your x-ui nodes automatically, no more hand-editing share links
- **Status page**: metrics, service checks, and control buttons you can tap from your phone
- **Uptime Kuma**: monitoring + Telegram alerts, pushed to your phone when a service dies
- **Weekly backup**: pack, sha256-verify, chunk, ship it off the machine, keep only the latest 4 copies
- **Cloudflare Tunnel**: every service gets a domain and HTTPS, with **zero inbound ports opened**

## Quick start

You need: one clean Debian/Ubuntu VPS (ARM or x86, 1 GB RAM is enough for most modules), root, and optionally a domain hosted on Cloudflare.

```bash
git clone https://github.com/<you>/freebox.git
cd freebox
cp config.example.env config.env   # fill in your own domain and tokens
sudo ./install.sh                  # all modules
# or just a few:
sudo ./install.sh adguard subhub backup
```

Every module also installs on its own — each folder under `modules/` has its own README and install script.

## Modules

| Module | What you get |
|---|---|
| `adguard` | One-command AdGuard Home deploy + uninstall |
| `subhub` | Subscription generation/distribution: describe a node once in JSON, get `/<token>` and `/<token>/<group>` URLs; remote node databases are pulled over scp, with automatic fallback to cache on failure |
| `status` | The status page I actually use (collector + web page + optional control API) |
| `monitor` | Uptime Kuma in Docker, bound to localhost only, with Telegram notification setup steps |
| `backup` | Weekly backup built on rclone: pack + sha256 + 400 MB chunks + keep only the latest 4 |
| `tunnel` | cloudflared install + ingress template + the Cloudflare Access setup I recommend |

## Why these pieces

Free machines fail in predictable ways: you forget what is running on them (status page), they die quietly at 3 a.m. (monitoring), backups fill the disk (rotation), one certificate renewal takes every HTTPS site down at once (cert chains, see below), a node changes and every subscription link rots (SubHub). FreeBox is not six tools thrown on a table. It is scar tissue, paid for in real incidents.

## Tuition already paid for you

- **Certificates**: some ACME setups install only the leaf certificate. After renewal the browser looks fine while strict verification fails everywhere. Use the full chain.
- **cron and timezones**: after you change the system timezone, cron may keep dispatching on the old one until you restart it. Judge whether a job ran by its output files, not by whether the crontab entry exists.
- **Backups**: never upload a >1 GB archive straight to Google Drive; it will get cut off. Chunk it (the backup module defaults to 400 MB), verify each chunk's size, and keep a second destination.
- **Web config directories**: never leave backup files inside a directory that is wildcard-included (like `sites-enabled/`). Deleted services will "resurrect" from their own backups.
- **Small-RAM machines**: install one module at a time and check `free -h` after each. Hope is not a memory management strategy.

## Security notes

- Bind services to `127.0.0.1` wherever possible; the tunnel is the door.
- A SubHub token is a password. The status page control API must sit behind authentication. Put admin entrances behind Cloudflare Access.
- `config.env`, tokens, and node databases are all gitignored. Do not commit them by hand.

## License

MIT. Take it, get your machine running, and come back and tell me when something breaks.
