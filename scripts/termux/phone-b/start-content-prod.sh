#!/data/data/com.termux/files/usr/bin/bash
# Start prod api-content (NestJS dist/main.js).
set -euo pipefail

NODE="/data/data/com.termux/files/usr/bin/node"
PKG_DIR="$HOME/phone-lab/packages/api-content-prod"
LOG_DIR="$HOME/phone-lab/logs"
LOG_FILE="$LOG_DIR/content-prod.log"

mkdir -p "$LOG_DIR"
cd "$PKG_DIR" || exit 1

if [ ! -f dist/src/main.js ]; then
  echo "ERROR: dist/src/main.js not found. Run npm install and ensure deploy extracted."
  exit 1
fi

if [ ! -f .env ]; then
  echo "ERROR: .env not found. cp .env.example .env"
  exit 1
fi

pgrep -f "$PKG_DIR/dist/src/main.js" >/dev/null && exit 0

echo "$(date -Iseconds) start: api-content-prod" >> "$LOG_FILE"
nohup "$NODE" dist/src/main.js >> "$LOG_FILE" 2>&1 &
echo "api-content-prod: started (port from .env, default 4004)"
