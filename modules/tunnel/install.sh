#!/usr/bin/env bash
# FreeBox Tunnel installer: Cloudflare Tunnel for your services.
# Gives every local service a public HTTPS name without opening ports.
# The login + DNS steps are interactive by design (they are YOUR Cloudflare
# account); this script automates everything around them.
set -euo pipefail

DOMAIN="${DOMAIN:-example.com}"
TUNNEL_NAME="${TUNNEL_NAME:-freebox}"

if [ "$(id -u)" -ne 0 ]; then echo "run as root" >&2; exit 1; fi

if ! command -v cloudflared >/dev/null; then
  echo "Installing cloudflared..."
  ARCH="$(dpkg --print-architecture)"
  curl -fsSL "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${ARCH}.deb" -o /tmp/cloudflared.deb
  dpkg -i /tmp/cloudflared.deb || apt-get install -f -y
fi

mkdir -p /etc/cloudflared
if [ ! -f /etc/cloudflared/config.yml ]; then
  cat > /etc/cloudflared/config.yml <<EOF
tunnel: $TUNNEL_NAME
credentials-file: /root/.cloudflared/<TUNNEL-UUID>.json

ingress:
  - hostname: status.$DOMAIN
    service: http://127.0.0.1:3001
  - hostname: sub.$DOMAIN
    service: http://127.0.0.1:8890
  - service: http_status:404
EOF
  echo "Wrote /etc/cloudflared/config.yml template."
fi

cat <<EOF

Manual steps (once, ~5 minutes):
  1) Authenticate:            cloudflared tunnel login
  2) Create the tunnel:       cloudflared tunnel create $TUNNEL_NAME
  3) Put the tunnel UUID into /etc/cloudflared/config.yml
     (credentials-file line) and adjust hostnames/services to your setup.
  4) Create DNS records:      cloudflared tunnel route dns $TUNNEL_NAME status.$DOMAIN
                              cloudflared tunnel route dns $TUNNEL_NAME sub.$DOMAIN
  5) Install as a service:    cloudflared service install
                              systemctl enable --now cloudflared

Strongly recommended: put your status page and monitor behind
Cloudflare Access (Zero Trust -> Access) with an "only my email" policy.
A login page you wrote yourself is not an access-control strategy.
EOF
