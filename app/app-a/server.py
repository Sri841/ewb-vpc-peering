#!/usr/bin/env python3
"""App-A: web + API tier (VPC A, private subnet). Serves the dashboard and talks to App-B
over the VPC peering connection using private IPs only. Standard library only."""
import json, mimetypes, os, re, shutil, socket, subprocess, time, urllib.error, urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

HOST = os.environ.get("HOST", "0.0.0.0")
PORT = int(os.environ.get("PORT", "8080"))
APP_B_IP = os.environ.get("APP_B_IP", "10.20.1.10")
APP_B_URL = os.environ.get("APP_B_URL", f"http://{APP_B_IP}:9000")
STATIC = os.path.join(os.path.dirname(os.path.abspath(__file__)), "static")
TIMEOUT = 3


def private_ips():
    try:
        return subprocess.check_output(["hostname", "-I"], text=True).split()
    except Exception:
        return [socket.gethostbyname(socket.gethostname())]


def call_b(path, payload=None):
    """Returns (ok, data_or_error, latency_ms)."""
    t0 = time.time()
    try:
        req = urllib.request.Request(APP_B_URL + path)
        if payload is not None:
            req = urllib.request.Request(APP_B_URL + path, data=json.dumps(payload).encode(),
                                         headers={"Content-Type": "application/json"}, method="POST")
        with urllib.request.urlopen(req, timeout=TIMEOUT) as r:
            return True, json.loads(r.read()), round((time.time() - t0) * 1000, 1)
    except urllib.error.URLError as e:
        return False, f"App-B unreachable: {e.reason}", round((time.time() - t0) * 1000, 1)
    except Exception as e:
        return False, f"App-B error: {e}", round((time.time() - t0) * 1000, 1)


def run_ping(ip, count=4):
    if not re.fullmatch(r"\d{1,3}(\.\d{1,3}){3}", ip):
        return {"error": "invalid ip"}
    exe = shutil.which("ping")
    if not exe:
        return {"error": "ping not installed on this host"}
    try:
        out = subprocess.run([exe, "-c", str(count), "-W", "2", ip], capture_output=True, text=True, timeout=count * 3 + 2).stdout
    except Exception as e:
        return {"error": str(e)}
    loss = re.search(r"([\d.]+)% packet loss", out)
    rx = re.search(r"(\d+) (?:packets )?received", out)
    return {"target": ip, "transmitted": count, "received": int(rx.group(1)) if rx else 0,
            "loss_pct": float(loss.group(1)) if loss else 100.0, "raw": out.strip().splitlines()[-3:]}


class Handler(BaseHTTPRequestHandler):
    def _json(self, code, obj):
        body = json.dumps(obj).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _static(self, path):
        rel = "index.html" if path in ("/", "") else path.lstrip("/")
        full = os.path.realpath(os.path.join(STATIC, rel))
        if not full.startswith(os.path.realpath(STATIC)) or not os.path.isfile(full):
            return self._json(404, {"error": "not found"})
        with open(full, "rb") as f:
            body = f.read()
        self.send_response(200)
        self.send_header("Content-Type", mimetypes.guess_type(full)[0] or "application/octet-stream")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        p = self.path.split("?")[0]
        if p == "/api/info":
            return self._json(200, {"service": "app-a", "vpc": "ewb-vpc-a", "hostname": socket.gethostname(),
                                    "private_ips": private_ips(), "app_b_url": APP_B_URL})
        if p == "/api/peer":
            ok, data, ms = call_b("/api/info")
            return self._json(200, {"reachable": ok, "latency_ms": ms, "app_b": data if ok else None,
                                    "error": None if ok else data})
        if p == "/api/ping":
            return self._json(200, run_ping(APP_B_IP))
        if p == "/api/notes":
            ok, data, _ = call_b("/api/notes")
            return self._json(200 if ok else 502, data if ok else {"error": data})
        self._static(p)

    def do_POST(self):
        if self.path != "/api/notes":
            return self._json(404, {"error": "not found"})
        try:
            n = int(self.headers.get("Content-Length", 0))
            payload = json.loads(self.rfile.read(n) or b"{}")
        except Exception:
            return self._json(400, {"error": "bad json"})
        ok, data, _ = call_b("/api/notes", payload)
        self._json(201 if ok else 502, data if ok else {"error": data})

    def log_message(self, fmt, *args):
        print("[app-a] %s - %s" % (self.client_address[0], fmt % args), flush=True)


if __name__ == "__main__":
    print(f"[app-a] listening on {HOST}:{PORT}, app-b={APP_B_URL}", flush=True)
    ThreadingHTTPServer((HOST, PORT), Handler).serve_forever()
