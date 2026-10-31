# Tunnel — Cloudflare Tunnel for every service

A free-tier VPS usually gets one public IP and a pile of services that all
want to be reachable. The old way is a port number for every service and a
firewall rule for every port. I switched everything to Cloudflare Tunnel
and never looked back:

- Services bind to `127.0.0.1` only. The tunnel reaches out to Cloudflare,
  so **no inbound ports need to be open at all**.
- Every service gets a real hostname with a valid certificate
  (`status.example.com`, `sub.example.com`, …).
- Cloudflare Access can sit in front of the sensitive ones (status page,
  monitor) with an email-only policy — proper access control instead of a
  hand-rolled login page.

`install.sh` installs cloudflared, drops a config template at
`/etc/cloudflared/config.yml`, and prints the five one-time steps (login,
create tunnel, route DNS, install service).

Pitfalls I hit so you don't have to:

- The catch-all rule (`http_status:404`) must be last in the ingress list
  or nothing else matches.
- After moving a hostname from a plain DNS record to a tunnel, delete the
  old A record first — `tunnel route dns` refuses to overwrite it.
- Certificates: when you terminate extra HTTPS services behind nginx
  instead of the tunnel, remember some ACME clients install only the leaf
  certificate. If strict verification fails everywhere after a renewal,
  check that the full chain is what nginx actually serves.
