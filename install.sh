#!/usr/bin/env bash
# FreeBox — one box, whole homelab.
# Turns a fresh (free-tier) VPS into a working self-hosted base:
# ad-blocking DNS, a proxy subscription hub, a status page, uptime
# monitoring with Telegram alerts, weekly off-site backups and a
# Cloudflare Tunnel so none of it needs open ports.
#
# Usage:
#   cp config.example.env config.env && nano config.env
#   sudo ./install.sh              # all modules
#   sudo ./install.sh subhub       # just one (or several)
#
# Every module is independent and safe to re-run.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
ALL_MODULES=(adguard subhub status monitor backup tunnel)

if [ "$(id -u)" -ne 0 ]; then echo "run as root: sudo ./install.sh" >&2; exit 1; fi

if [ ! -f "$ROOT/config.env" ]; then
  cp "$ROOT/config.example.env" "$ROOT/config.env"
  echo "Created config.env from the example. Edit it later in place;"
  echo "continuing with defaults for now."
fi
set -a; # shellcheck disable=SC1091
. "$ROOT/config.env"; set +a

if [ $# -gt 0 ]; then MODULES=("$@"); else MODULES=("${ALL_MODULES[@]}"); fi

for m in "${MODULES[@]}"; do
  dir="$ROOT/modules/$m"
  if [ ! -d "$dir" ]; then echo "!! unknown module: $m" >&2; continue; fi
  echo
  echo "================ module: $m ================"
  if [ -x "$dir/install.sh" ]; then
    bash "$dir/install.sh"
  else
    echo "No installer for '$m' — it ships as code + deploy examples."
    echo "See $dir/README.md and $dir/deploy/ for the manual steps."
  fi
done

echo
echo "=================================================="
echo "FreeBox base is in. Final checklist:"
echo "  [ ] Point your router/devices at the AdGuard DNS if you use it at home"
echo "  [ ] Fill in every module's config with YOUR values (domains, tokens)"
echo "  [ ] Create the Uptime Kuma admin account + Telegram notification"
echo "  [ ] Run one backup by hand and verify it on the receiving side"
echo "  [ ] Put status/monitor behind Cloudflare Access or a password"
echo "Report memory after installs on small boxes: free -h"
