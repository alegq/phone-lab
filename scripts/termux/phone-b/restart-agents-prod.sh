#!/data/data/com.termux/files/usr/bin/bash
# Restart api-agents-prod without full data-plane boot.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PKG_DIR="$HOME/phone-lab/packages/api-agents-prod"

pkill -f "$PKG_DIR/dist/main.js" 2>/dev/null || true
fuser -k 4010/tcp 2>/dev/null || true
sleep 2
bash "$SCRIPT_DIR/start-agents-prod.sh"
