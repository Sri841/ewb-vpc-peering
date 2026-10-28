#!/usr/bin/env bash
# Copies the app to App-A and App-B THROUGH the bastion (ProxyJump) and starts systemd services.
# No internet needed on the private instances: the app is pure Python standard library.
set -euo pipefail
source "$(dirname "$0")/_common.sh"

deploy() {  # host dirname service envline
  local host=$1 dir=$2 svc=$3 envline=$4
  echo ">> deploying $svc to $host"
  tar czf - -C "$ROOT/app/$dir" . | $SSH "$host" "sudo mkdir -p /opt/ewb/$dir && sudo tar xzf - -C /opt/ewb/$dir && sudo chown -R ec2-user:ec2-user /opt/ewb"
  $SSH "$host" "sudo tee /etc/systemd/system/$svc.service >/dev/null" <<UNIT
[Unit]
Description=EWB $svc
After=network.target
[Service]
User=ec2-user
$envline
ExecStart=/usr/bin/python3 /opt/ewb/$dir/server.py
Restart=always
[Install]
WantedBy=multi-user.target
UNIT
  $SSH "$host" "sudo systemctl daemon-reload && sudo systemctl enable --now $svc && sleep 1 && systemctl is-active $svc"
}

deploy ewb-app-b app-b ewb-app-b "Environment=DATA_FILE=/home/ec2-user/notes.json"
deploy ewb-app-a app-a ewb-app-a "Environment=APP_B_IP=10.20.1.10"
echo "Done. Run: bash scripts/tunnel.sh   then open http://localhost:8080"
