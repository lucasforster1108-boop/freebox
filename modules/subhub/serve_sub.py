#!/usr/bin/env python3
"""FreeBox SubHub server.

Serves the subscription files built by build_sub.py under a secret token:

    /<token>            -> all nodes        (sub_all.txt)
    /<token>/<group>    -> one group        (sub_<group>.txt)

Anything else gets a 404. The token lives in token.txt next to this file
(or the SUBHUB_TOKEN environment variable). Stdlib only.
"""
import http.server
import json
import os
import socketserver

HERE = os.path.dirname(os.path.abspath(__file__))


def load_cfg():
    path = os.path.join(HERE, "config.json")
    cfg = {}
    if os.path.exists(path):
        cfg = json.load(open(path))
    token = os.environ.get("SUBHUB_TOKEN", "").strip()
    if not token:
        token_file = os.path.join(HERE, "token.txt")
        token = open(token_file).read().strip()
    return {
        "port": int(os.environ.get("SUBHUB_PORT", cfg.get("serve_port", 8890))),
        "token": token,
        "out_dir": cfg.get("output_dir", HERE),
        "titles": cfg.get("group_titles", {}),
    }


CFG = load_cfg()


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        parts = self.path.strip("/").split("/")
        if not parts or parts[0] != CFG["token"]:
            return self._reply(404)
        if len(parts) == 1:
            fname, title = "sub_all.txt", CFG["titles"].get("all", "FreeBox-All")
        elif len(parts) == 2:
            fname = f"sub_{parts[1]}.txt"
            title = CFG["titles"].get(parts[1], f"FreeBox-{parts[1]}")
        else:
            return self._reply(404)
        try:
            with open(os.path.join(CFG["out_dir"], fname), "rb") as f:
                body = f.read()
        except OSError:
            return self._reply(404)
        self.send_response(200)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Profile-Title", title)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _reply(self, code):
        self.send_response(code)
        self.end_headers()

    def log_message(self, *args):
        pass


if __name__ == "__main__":
    socketserver.ThreadingTCPServer.allow_reuse_address = True
    with socketserver.ThreadingTCPServer(("0.0.0.0", CFG["port"]), Handler) as httpd:
        print(f"SubHub serving on :{CFG['port']}")
        httpd.serve_forever()
