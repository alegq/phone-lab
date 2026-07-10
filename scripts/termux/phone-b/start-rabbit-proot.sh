#!/data/data/com.termux/files/usr/bin/bash
# Start RabbitMQ inside proot Debian (phone-b boot).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/proot-env.sh"

mkdir -p "$LOG_DIR"
WAIT_SECONDS="${RABBITMQ_START_TIMEOUT:-300}"

rabbit_proot_supervisor_running() {
  pgrep -f "proot-distro login ${PROOT_DISTRO} -- rabbitmq-server" >/dev/null 2>&1
}

if rabbitmq_proot_ping; then
  echo "rabbitmq-proot: already running"
  exit 0
fi

if rabbit_proot_supervisor_running; then
  echo "rabbitmq-proot: supervisor already starting"
else
  echo "$(date -Iseconds) start-rabbit-proot: launching foreground server in background proot" >> "$RMQ_PROOT_LOG"
  # proot-distro uses --kill-on-exit: rabbit must run inside a long-lived proot session.
  nohup proot-distro login "$PROOT_DISTRO" -- rabbitmq-server >> "$RMQ_PROOT_LOG" 2>&1 &
fi

iterations=$((WAIT_SECONDS / 5))
for _ in $(seq 1 "$iterations"); do
  if rabbitmq_proot_ping; then
    echo "rabbitmq-proot: started"
    exit 0
  fi
  sleep 5
done

echo "ERROR: rabbitmq-proot failed to start within ${WAIT_SECONDS}s"
echo "--- tail $RMQ_PROOT_LOG ---"
tail -30 "$RMQ_PROOT_LOG" 2>/dev/null || true
exit 1
