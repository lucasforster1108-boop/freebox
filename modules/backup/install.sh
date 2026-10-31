#!/usr/bin/env bash
# FreeBox Backup installer: installs backup.sh to /opt/freebox-backup and
# schedules it weekly (Sunday 03:23 server time). Uploads go through rclone,
# so configure a remote first:  rclone config
set -euo pipefail

SRC="$(cd "$(dirname "$0")" && pwd)"
DEST="/opt/freebox-backup"

if [ "$(id -u)" -ne 0 ]; then echo "run as root" >&2; exit 1; fi
command -v rclone >/dev/null || echo "NOTE: rclone not found yet. Install it (https://rclone.org/install/) and run 'rclone config' before the first backup."

mkdir -p "$DEST"
install -m 0755 "$SRC/backup.sh" "$DEST/backup.sh"
[ -f "$DEST/backup.conf" ] || install -m 0600 "$SRC/backup.conf.example" "$DEST/backup.conf"

CRON_LINE="23 3 * * 0 root $DEST/backup.sh >> $DEST/logs/cron.log 2>&1"
grep -qs "freebox-backup/backup.sh" /etc/cron.d/freebox-backup 2>/dev/null || echo "$CRON_LINE" > /etc/cron.d/freebox-backup

echo
echo "Backup installed."
echo "  1) Edit $DEST/backup.conf: source dirs, rclone remote, keep count."
echo "  2) Test once by hand before trusting the cron:  $DEST/backup.sh"
echo "  3) Verify the uploaded files AND the sha256 on the receiving side."
echo "     A backup you never test-restored is a hope, not a backup."
