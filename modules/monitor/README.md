# Monitor — Uptime Kuma + Telegram alerts

A homelab you don't monitor is just a pile of future surprises. This module
runs [Uptime Kuma](https://github.com/louislam/uptime-kuma) in Docker,
bound to localhost, and walks you through wiring its alerts to Telegram so
a dead service pings your phone instead of waiting to be discovered.

What I monitor on my own box, steal this list:

- Every public web entry (status page, file drive, RSS, converter) as an
  HTTP keyword check, not just a ping.
- The subscription server port (TCP).
- Push monitors for hosts that can't be reached directly: the remote box
  curls Kuma's push URL every minute, and Kuma alerts when a beat is missed.

Setup details live in `install.sh`'s closing notes. Keep Kuma itself behind
your reverse proxy or tunnel with authentication in front — its admin panel
is not something to leave naked on the internet.
