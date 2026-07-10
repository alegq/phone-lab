#!/data/data/com.termux/files/usr/bin/bash
# Restart prod api-marketing.
set -euo pipefail

PKG_DIR="$HOME/phone-lab/packages/api-marketing-prod"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

pkill -f "$PKG_DIR/dist/main.js" 2>/dev/null || true
fuser -k 4008/tcp 2>/dev/null || true
sleep 2

bash "$SCRIPT_DIR/start-redis.sh" || true
bash "$SCRIPT_DIR/start-marketing-prod.sh"
