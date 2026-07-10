set -euo pipefail

CONFIG="${1:-$HOME/phone-lab/cloudflared/config.yml}"

if [ ! -f "$CONFIG" ]; then
  echo "Missing config: $CONFIG"
  echo "Copy from: ~/phone-lab/scripts/cloudflared/phone-a/config.yml.example"
  exit 1
fi

export PATH="$HOME/bin:$PATH"

LOG_DIR="$HOME/phone-lab/logs"
mkdir -p "$LOG_DIR"

echo "[cloudflared] Starting tunnel with $CONFIG"
echo "[cloudflared] Logging to $LOG_DIR/cloudflared-phone-a.log"

nohup cloudflared tunnel --config "$CONFIG" run \
  >>"$LOG_DIR/cloudflared-phone-a.log" 2>&1 &

sleep 1
pgrep -af cloudflared || true

