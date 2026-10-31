#!/usr/bin/env python3
"""FreeBox SubHub builder.

Builds proxy subscription files (base64) from a list of nodes defined in
config.json. Two node kinds are supported:

  - "xui-db":   read a 3x-ui / x-ui SQLite database (local path, or fetched
                over scp first) and derive the VLESS+Reality share link from
                the inbound matching "inbound_port".
  - "link-file": take ready-made share links from a text file (one per line).

Design rules learned the hard way:
  - A remote fetch that fails must never kill the whole build: fall back to
    the last cached copy.
  - One broken node must not take the others down with it.
  - Output files are written atomically and chmod 600.
"""
import base64
import json
import os
import shutil
import sqlite3
import subprocess
import sys
import urllib.parse

HERE = os.path.dirname(os.path.abspath(__file__))
CONFIG = os.path.join(HERE, "config.json")


def pubkey_from_priv(xray_bin, priv):
    out = subprocess.run([xray_bin, "x25519", "-i", priv],
                         capture_output=True, text=True).stdout
    for line in out.splitlines():
        if "PublicKey" in line or "Public key" in line:
            return line.split(":", 1)[1].strip().split()[-1]
    raise RuntimeError("could not derive public key")


def link_from_db(cfg, node):
    db_path = node["db"]
    fetch = node.get("fetch")
    if fetch:
        cache = fetch["cache"]
        os.makedirs(os.path.dirname(cache), exist_ok=True)
        tmp = cache + ".tmp"
        cmd = ["scp", "-o", "BatchMode=yes", "-o", "StrictHostKeyChecking=no",
               "-o", "ConnectTimeout=20"]
        if fetch.get("key"):
            cmd += ["-i", os.path.expanduser(fetch["key"])]
        cmd += [fetch["source"], tmp]
        ok = False
        try:
            r = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
            if r.returncode == 0 and os.path.getsize(tmp) > 0:
                shutil.move(tmp, cache)
                ok = True
                print(f"[{node['name']}] db fetched fresh")
        except Exception as e:  # noqa: BLE001 - fallback is the point
            print(f"[{node['name']}] fetch error: {type(e).__name__}")
        if os.path.exists(tmp):
            os.unlink(tmp)
        if not ok:
            if not os.path.exists(cache):
                raise RuntimeError("fetch failed and no cached db")
            print(f"[{node['name']}] using cached db")
        db_path = cache

    port = node.get("inbound_port", 443)
    db = sqlite3.connect(db_path)
    row = db.execute(
        "select settings, stream_settings from inbounds where port=?",
        (port,)).fetchone()
    db.close()
    if not row:
        raise RuntimeError(f"no inbound on port {port}")
    settings, stream = row
    client = json.loads(settings)["clients"][0]
    reality = json.loads(stream)["realitySettings"]
    pub = pubkey_from_priv(cfg["xray_bin"], reality["privateKey"])
    q = {"encryption": "none",
         "flow": client.get("flow", "xtls-rprx-vision"),
         "security": "reality",
         "sni": (reality.get("serverNames") or ["www.apple.com"])[0],
         "fp": "chrome", "pbk": pub, "type": "tcp"}
    sid = (reality.get("shortIds") or [""])[0]
    if sid:
        q["sid"] = sid
    link = ("vless://" + client["id"] + "@" + node["host"] + ":"
            + str(node.get("port", port)) + "?"
            + urllib.parse.urlencode(q) + "#"
            + urllib.parse.quote(node["name"]))
    return link


def node_links(cfg, node):
    kind = node["type"]
    if kind == "xui-db":
        return [link_from_db(cfg, node)]
    if kind == "link-file":
        path = node["file"]
        if not os.path.isabs(path):
            path = os.path.join(HERE, path)
        links = []
        for line in open(path):
            line = line.strip()
            if line and not line.startswith("#"):
                links.append(line)
        return links
    raise RuntimeError(f"unknown node type: {kind}")


def write_out(path, text):
    tmp = path + ".tmp"
    with open(tmp, "w") as f:
        f.write(text)
    os.chmod(tmp, 0o600)
    os.replace(tmp, path)


def main():
    cfg = json.load(open(CONFIG))
    out_dir = cfg.get("output_dir", HERE)
    os.makedirs(out_dir, exist_ok=True)
    groups = {}
    all_links = []
    built = 0
    for node in cfg["nodes"]:
        try:
            links = node_links(cfg, node)
        except Exception as e:  # noqa: BLE001 - keep other nodes alive
            print(f"[{node.get('name', '?')}] SKIPPED: {e}")
            continue
        built += 1
        group = node.get("group", "all")
        groups.setdefault(group, []).extend(links)
        all_links.extend(links)
        print(f"[{node['name']}] ok ({len(links)} link(s), group={group})")
    if built == 0:
        print("no node could be built; leaving previous files untouched")
        return 1
    write_out(os.path.join(out_dir, "sub_all.txt"),
              base64.b64encode(("\n".join(all_links) + "\n").encode()).decode())
    for group, links in groups.items():
        if group == "all":
            continue
        write_out(os.path.join(out_dir, f"sub_{group}.txt"),
                  base64.b64encode(("\n".join(links) + "\n").encode()).decode())
    summary = [{"name": n["name"], "group": n.get("group", "all"),
                "host": n.get("host", "-")} for n in cfg["nodes"]]
    write_out(os.path.join(out_dir, "nodes_summary.json"),
              json.dumps(summary, indent=2))
    print(f"built {built} node(s), {len(all_links)} link(s) total")
    return 0


if __name__ == "__main__":
    sys.exit(main())
