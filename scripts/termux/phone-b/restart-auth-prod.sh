#!/data/data/com.termux/files/usr/bin/bash
# Restart prod api-auth on phone-b.
set -euo pipefail

PKG_DIR="$HOME/phone-lab/packages/api-auth-prod"

pkill -f "$PKG_DIR/dist/main.js" 2>/dev/null || true
sleep 2

bash "$PKG_DIR/scripts/termux/phone-b/start-auth-prod.sh"

