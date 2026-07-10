#!/data/data/com.termux/files/usr/bin/bash
# Start Redis for api-marketing (phone-b or phone-a).
set -euo pipefail

LOG_DIR="${LOG_DIR:-$HOME/phone-lab/logs}"
mkdir -p "$LOG_DIR"

if ! command -v redis-server >/dev/null 2>&1; then
  echo "redis-server not found; run install-marketing-deps.sh"
  exit 1
fi

if pgrep -x redis-server >/dev/null 2>&1; then
  echo "redis: already running"
  exit 0
fi

redis-server --daemonize yes --port 6379 --bind 127.0.0.1 \
  --logfile "$LOG_DIR/redis.log" \
  --requirepass password123 2>/dev/null || redis-server --daemonize yes --port 6379 --bind 127.0.0.1

echo "redis: started on 127.0.0.1:6379"
