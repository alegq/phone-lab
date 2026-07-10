#!/data/data/com.termux/files/usr/bin/bash
# Start prod api-agents on phone-b (NestJS dist/main.js).
set -euo pipefail

NODE="/data/data/com.termux/files/usr/bin/node"
PKG_DIR="$HOME/phone-lab/packages/api-agents-prod"
LOG_DIR="$HOME/phone-lab/logs"
LOG_FILE="$LOG_DIR/agents-prod.log"

mkdir -p "$LOG_DIR"
cd "$PKG_DIR" || exit 1

if [ ! -f dist/main.js ]; then
  echo "ERROR: dist/main.js not found. Run npm install and ensure deploy extracted."
  exit 1
fi

if [ ! -f .env ]; then
  echo "ERROR: .env not found. cp .env.example .env"
  exit 1
fi

pgrep -f "$PKG_DIR/dist/main.js" >/dev/null && exit 0

echo "$(date -Iseconds) start: api-agents-prod" >> "$LOG_FILE"
nohup "$NODE" dist/main.js >> "$LOG_FILE" 2>&1 &
echo "api-agents-prod: started (port from .env, default 4010)"
