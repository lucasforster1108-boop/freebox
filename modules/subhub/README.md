# SubHub — subscription builder & server

I run proxy nodes on several small servers. Every client app wants a
subscription URL, and every time a node changes (new key, new port, rebuilt
box) I used to edit links by hand in three places. SubHub is the piece that
ended that: nodes are described once in `config.json`, share links are
derived automatically, and one token URL serves the result.

## How it works

- `build_sub.py` — reads `config.json`, produces base64 subscription files:
  `sub_all.txt` plus one `sub_<group>.txt` per group.
  - `xui-db` nodes: the VLESS+Reality link is derived straight from a
    3x-ui / x-ui SQLite database (public key computed from the private key,
    so it can never drift from the server). A node on another machine can be
    `fetch`ed over scp first; if the fetch fails, the last cached copy is
    used and the build still succeeds.
  - `link-file` nodes: ready-made share links from a text file, for nodes
    that don't run x-ui.
- `serve_sub.py` — tiny stdlib HTTP server. `/<token>` serves all nodes,
  `/<token>/<group>` serves one group. Everything else is a 404.
- A cron job rebuilds daily; a systemd unit serves 24/7.

## Install

```bash
sudo ./install.sh
```

Then edit `/opt/subhub/config.json`, run the first build, and add the
printed URL to your client (v2rayNG, Streisand, Hiddify, sing-box, …).

Notes from running this in production:

- The subscription token is the only credential. Treat the URL like a
  password, and don't expose the plain HTTP port to the open internet
  without a reverse proxy or tunnel in front of it.
- Group names become URL parts, so keep them lowercase ASCII.
- Firewall: the serve port only needs to be reachable by *you* (and by any
  mirror you sync to). Mine also pushes the built files to a second host
  with scp — a 10-line shell script is enough, copy the pattern from
  `build_sub.py`'s fetch logic in reverse.
