#!/data/data/com.termux/files/usr/bin/bash
# Restart prod api-content.
set -euo pipefail

PKG_DIR="$HOME/phone-lab/packages/api-content-prod"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

pkill -f "$PKG_DIR/dist/src/main.js" 2>/dev/null || true
fuser -k 4004/tcp 2>/dev/null || true
sleep 2

bash "$SCRIPT_DIR/start-content-prod.sh"
