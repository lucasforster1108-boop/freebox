# Status — a status page for your box

A small self-hosted status page: system metrics, service checks and traffic
counters rendered as a single page, with a tiny control API for the
actions you actually need from your phone (restart a service, renew a
subscription, reboot). This is the same code I run on my own box,
sanitized — it also lives as its own repo (`vps-status-page`) if you only
want this piece.

Layout:

- `collector/check_status.py` — gathers metrics into `status.json` (run it
  from cron every minute).
- `web/index.html` — the page itself; it just reads `status.json`.
- `control/control_api.py` — optional control endpoints. Read the code
  before enabling it: anything that can restart services must sit behind
  authentication and never be exposed bare.
- `deploy/` — crontab and nginx/systemd examples.
- `config.example.json` — copy to `config.json` and describe your services.

Before you ship a page like this, extract its inline script and syntax
check it (`node --check`) — an HTTP 200 tells you nothing about whether
the page actually renders.
