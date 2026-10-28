#!/usr/bin/env bash
# Workbook page 11 acceptance tests. Save the output as your evidence.
# Usage: bash scripts/tests.sh [baseline|after|all]
source "$(dirname "$0")/_common.sh"
mode="${1:-all}"
hr() { printf '\n===== %s =====\n' "$1"; }

baseline() {
  hr "01 / Baseline: App-A -> App-B (expect NO replies before peering)"
  $SSH ewb-app-a 'hostname; hostname -I; ping -c 4 -W 2 10.20.1.10; echo "exit=$?"'
}
after() {
  hr "02 / Forward path: App-A -> App-B (expect 4 replies, 0% loss)"
  $SSH ewb-app-a 'hostname; hostname -I; ping -c 4 10.20.1.10'
  hr "03 / Reverse path: App-B -> App-A (expect 4 replies, 0% loss)"
  $SSH ewb-app-b 'hostname; hostname -I; ping -c 4 10.10.2.10'
  hr "04 / Private SSH: laptop -> bastion -> App-B"
  $SSH ewb-app-b 'echo "connected to $(hostname) $(hostname -I)"'
  hr "05 / Isolation: no public IPv4 on App-A / App-B"
  $SSH ewb-app-a 'TOKEN=$(curl -s -X PUT http://169.254.169.254/latest/api/token -H "X-aws-ec2-metadata-token-ttl-seconds: 30"); echo "App-A public-ipv4: $(curl -s -o /dev/null -w "%{http_code}" -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/public-ipv4) (404 = none)"'
  $SSH ewb-app-b 'TOKEN=$(curl -s -X PUT http://169.254.169.254/latest/api/token -H "X-aws-ec2-metadata-token-ttl-seconds: 30"); echo "App-B public-ipv4: $(curl -s -o /dev/null -w "%{http_code}" -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/public-ipv4) (404 = none)"'
  hr "06 / App layer: App-A -> App-B over TCP 9000"
  $SSH ewb-app-a 'curl -s --max-time 3 http://10.20.1.10:9000/api/info || echo "App-B API unreachable"'
}
case "$mode" in baseline) baseline;; after) after;; *) baseline; after;; esac
