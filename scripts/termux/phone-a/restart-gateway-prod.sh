#!/data/data/com.termux/files/usr/bin/bash
# Restart prod api-gateway on phone-a (picks up .env changes).
set -euo pipefail

PKG_DIR="$HOME/phone-lab/packages/api-gateway-prod"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

pkill -9 -f "$PKG_DIR/dist/main.js" 2>/dev/null || true
pkill -9 -f "packages/api-gateway-prod/dist/main.js" 2>/dev/null || true
fuser -k 4000/tcp 2>/dev/null || true
sleep 2

sed -i 's/\r$//' "$PKG_DIR/.env" 2>/dev/null || true
bash "$SCRIPT_DIR/start-gateway-prod.sh"
