#!/usr/bin/env bash
# FreeBox SubHub installer: installs to /opt/subhub, creates the serve
# service and a daily rebuild cron. Safe to re-run.
set -euo pipefail

SRC="$(cd "$(dirname "$0")" && pwd)"
DEST="/opt/subhub"

if [ "$(id -u)" -ne 0 ]; then echo "run as root" >&2; exit 1; fi
command -v python3 >/dev/null || { echo "python3 is required" >&2; exit 1; }

mkdir -p "$DEST/links" "$DEST/cache"
install -m 0644 "$SRC/build_sub.py" "$SRC/serve_sub.py" "$DEST/"
[ -f "$DEST/config.json" ] || install -m 0600 "$SRC/config.example.json" "$DEST/config.json"
[ -f "$DEST/links/extra.txt" ] || printf '# one share link per line\n' > "$DEST/links/extra.txt"

if [ ! -s "$DEST/token.txt" ]; then
  if [ -n "${SUB_TOKEN:-}" ]; then
    printf '%s' "$SUB_TOKEN" > "$DEST/token.txt"
  else
    head -c 24 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 32 > "$DEST/token.txt"
  fi
  chmod 600 "$DEST/token.txt"
fi

cat > /etc/systemd/system/subhub-serve.service <<EOF
[Unit]
Description=FreeBox SubHub subscription server
After=network.target

[Service]
Type=simple
WorkingDirectory=$DEST
ExecStart=/usr/bin/python3 $DEST/serve_sub.py
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now subhub-serve.service

# Daily rebuild at 04:20 (server local time). Check your timezone first:
# if you changed the system timezone, restart cron or jobs fire on the old one.
CRON_LINE="20 4 * * * root /usr/bin/python3 $DEST/build_sub.py >> $DEST/build.log 2>&1"
grep -qs "build_sub.py" /etc/cron.d/subhub 2>/dev/null || echo "$CRON_LINE" > /etc/cron.d/subhub

TOKEN="$(cat "$DEST/token.txt")"
PORT="$(python3 -c "import json;print(json.load(open('$DEST/config.json')).get('serve_port',8890))")"
echo
echo "SubHub installed."
echo "  1) Edit $DEST/config.json and describe YOUR nodes."
echo "  2) Run the first build:  python3 $DEST/build_sub.py"
echo "  3) Subscription URL:     http://<this-server-ip>:$PORT/$TOKEN"
echo "     Per-group URLs:       http://<this-server-ip>:$PORT/$TOKEN/<group>"
echo "  Keep the token secret. Put a reverse proxy / tunnel in front if you"
echo "  expose this beyond your own network."
