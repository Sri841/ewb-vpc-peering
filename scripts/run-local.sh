#!/usr/bin/env bash
# Run App-B (9000) and App-A (8080) on your laptop to develop the UI before touching AWS.
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$ROOT/.local-data"
trap 'kill 0' EXIT
DATA_FILE="$ROOT/.local-data/notes.json" HOST=127.0.0.1 PORT=9000 python3 "$ROOT/app/app-b/server.py" &
sleep 1
HOST=127.0.0.1 PORT=8080 APP_B_IP=127.0.0.1 APP_B_URL=http://127.0.0.1:9000 python3 "$ROOT/app/app-a/server.py" &
echo "Open http://localhost:8080  (Ctrl+C to stop)"
wait
