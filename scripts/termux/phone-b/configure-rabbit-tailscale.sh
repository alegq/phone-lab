#!/data/data/com.termux/files/usr/bin/bash
# Expose RabbitMQ in proot Debian on Tailscale (phone-b) for cross-phone AMQP (phase 9).
# Run once on phone-b after setup-rabbit-proot.sh. Restarts Rabbit if config changed.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/proot-env.sh"

mkdir -p "$LOG_DIR"

if ! proot_distro_installed; then
  echo "ERROR: proot distro '$PROOT_DISTRO' not installed."
  exit 1
fi

echo "=== Phone Lab: configure RabbitMQ for Tailscale (phone-b) ==="

proot_run bash -s <<'INNER'
set -euo pipefail
mkdir -p /etc/rabbitmq
cat > /etc/rabbitmq/rabbitmq.conf <<'RMQCONF'
listeners.tcp.default = 5672
loopback_users = none
vm_memory_high_watermark.relative = 0.4
disk_free_limit.absolute = 256MB
RMQCONF
INNER

echo "Restarting RabbitMQ..."
proot_run rabbitmqctl stop 2>/dev/null || true
sleep 2

# Ensure supervisor is up; start-rabbit-proot.sh already waits for ping.
bash "$SCRIPT_DIR/start-rabbit-proot.sh"

WAIT_SECONDS="${RABBITMQ_START_TIMEOUT:-300}"
iterations=$((WAIT_SECONDS / 5))
for _ in $(seq 1 "$iterations"); do
  if rabbitmq_proot_ping; then
    echo "OK  rabbitmq-diagnostics ping"
    break
  fi
  sleep 5
done

if ! rabbitmq_proot_ping; then
  echo "ERROR: RabbitMQ not running after Tailscale config"
  echo "--- tail $RMQ_PROOT_LOG ---"
  tail -30 "$RMQ_PROOT_LOG" 2>/dev/null || true
  exit 1
fi

if amqp_port_open; then
  echo "OK  AMQP port ${RMQ_PORT} open on 127.0.0.1 (forwarded from proot)"
else
  echo "WARN: port ${RMQ_PORT} not open from Termux — proot may still accept via forwarded port"
fi

echo "Gateway on phone-a should use:"
echo "  amqp://${RMQ_USER}:***@100.103.183.36:${RMQ_PORT}"
echo "=== configure-rabbit-tailscale complete ==="
