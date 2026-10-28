ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CFG="$ROOT/ssh_config"
[ -f "$CFG" ] || { echo "ssh_config not found. Run 'terraform apply' in ./terraform first."; exit 1; }
SSH="ssh -F $CFG"
