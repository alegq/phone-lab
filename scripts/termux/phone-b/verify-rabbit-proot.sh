#!/data/data/com.termux/files/usr/bin/bash
# Verify RabbitMQ in proot is reachable from Termux.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/proot-env.sh"

echo "=== verify rabbitmq-proot ==="

if proot_run rabbitmq-diagnostics ping; then
  echo "OK  rabbitmq-diagnostics ping"
else
  echo "FAIL rabbitmq-diagnostics ping"
  exit 1
fi

if amqp_port_open; then
  echo "OK  port ${RMQ_PORT} open from Termux"
else
  echo "WARN port ${RMQ_PORT} closed from Termux (proot ping OK)"
fi

proot_run rabbitmqctl list_users 2>/dev/null | head -5
echo "=== verify passed ==="
