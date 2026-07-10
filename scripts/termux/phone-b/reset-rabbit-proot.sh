#!/data/data/com.termux/files/usr/bin/bash
# Reset RabbitMQ state inside proot and re-run setup (lab only).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/proot-env.sh"

proot_run bash -c '
  pid=$(pgrep -f "beam.smp.*rabbit" | head -1 || true)
  if [ -n "$pid" ]; then kill "$pid" 2>/dev/null || true; sleep 2; fi
  rabbitmqctl stop 2>/dev/null || true
  rm -rf /var/lib/rabbitmq/mnesia/* 2>/dev/null || true
' || true

bash "$SCRIPT_DIR/setup-rabbit-proot.sh"
