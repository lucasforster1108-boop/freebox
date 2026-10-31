#!/usr/bin/env bash
# FreeBox Monitor installer: Uptime Kuma via Docker, bound to localhost.
# Expose it through your reverse proxy / tunnel, not directly.
set -euo pipefail

SRC="$(cd "$(dirname "$0")" && pwd)"
DEST="/opt/freebox-monitor"

if [ "$(id -u)" -ne 0 ]; then echo "run as root" >&2; exit 1; fi

if ! command -v docker >/dev/null; then
  echo "Docker not found, installing..."
  curl -fsSL https://get.docker.com | sh
fi
mkdir -p "$DEST"
install -m 0644 "$SRC/docker-compose.yml" "$DEST/docker-compose.yml"
cd "$DEST"
docker compose up -d
echo
echo "Uptime Kuma is up on http://127.0.0.1:3001 (localhost only)."
echo "Next steps:"
echo "  1) Open it through your tunnel/reverse proxy and create the admin account."
echo "  2) Settings -> Notifications -> add Telegram: paste your bot token and"
echo "     chat ID, set it as default so every monitor alerts you."
echo "  3) Add monitors for every service you care about (HTTP keyword checks"
echo "     beat plain pings: they catch 'process up, page broken')."
