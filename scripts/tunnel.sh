#!/usr/bin/env bash
# SSH tunnel: laptop:8080 -> bastion -> App-A:8080. App-A never gets a public IP.
source "$(dirname "$0")/_common.sh"
echo "Open http://localhost:8080 (Ctrl+C to close)"
exec $SSH -N -L 8080:10.10.2.10:8080 ewb-bastion
