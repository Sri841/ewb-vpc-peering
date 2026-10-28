#!/usr/bin/env python3
"""App-B: private data service (VPC B). Stores notes in a JSON file.
Zero dependencies - private instances have no internet, so only the standard library is used."""
import json, os, socket, subprocess, threading, time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

HOST = os.environ.get("HOST", "0.0.0.0")
PORT = int(os.environ.get("PORT", "9000"))
DATA_FILE = os.environ.get("DATA_FILE", os.path.join(os.path.dirname(os.path.abspath(__file__)), "notes.json"))
LOCK = threading.Lock()
STARTED = time.time()


def private_ips():
    try:
        return subprocess.check_output(["hostname", "-I"], text=True).split()
    except Exception:
        return [socket.gethostbyname(socket.gethostname())]


def load():
    try:
        with open(DATA_FILE) as f:
            return json.load(f)
    except Exception:
        return []


def save(notes):
    os.makedirs(os.path.dirname(DATA_FILE), exist_ok=True)
    with open(DATA_FILE, "w") as f:
        json.dump(notes, f, indent=2)


class Handler(BaseHTTPRequestHandler):
    def _json(self, code, obj):
        body = json.dumps(obj).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path == "/health":
            return self._json(200, {"ok": True})
        if self.path == "/api/info":
            return self._json(200, {
                "service": "app-b", "vpc": "ewb-vpc-b",
                "hostname": socket.gethostname(), "private_ips": private_ips(),
                "seen_client_ip": self.client_address[0],  # should be 10.10.2.10 over peering
                "uptime_s": int(time.time() - STARTED),
            })
        if self.path == "/api/notes":
            with LOCK:
                return self._json(200, load())
        self._json(404, {"error": "not found"})

    def do_POST(self):
        if self.path != "/api/notes":
            return self._json(404, {"error": "not found"})
        try:
            n = int(self.headers.get("Content-Length", 0))
            data = json.loads(self.rfile.read(n) or b"{}")
            text = str(data.get("text", "")).strip()[:280]
            author = str(data.get("author", "anonymous")).strip()[:40] or "anonymous"
        except Exception:
            return self._json(400, {"error": "bad json"})
        if not text:
            return self._json(400, {"error": "text required"})
        with LOCK:
            notes = load()
            note = {"id": (notes[-1]["id"] + 1) if notes else 1, "author": author, "text": text,
                    "ts": time.strftime("%Y-%m-%d %H:%M:%S"), "from_ip": self.client_address[0]}
            notes.append(note)
            save(notes[-200:])
        self._json(201, note)

    def log_message(self, fmt, *args):
        print("[app-b] %s - %s" % (self.client_address[0], fmt % args), flush=True)


if __name__ == "__main__":
    print(f"[app-b] listening on {HOST}:{PORT}, data={DATA_FILE}", flush=True)
    ThreadingHTTPServer((HOST, PORT), Handler).serve_forever()
