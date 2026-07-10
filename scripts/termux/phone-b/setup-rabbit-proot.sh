#!/data/data/com.termux/files/usr/bin/bash
# One-time: install and configure RabbitMQ inside proot Debian.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/proot-env.sh"

mkdir -p "$LOG_DIR"

if ! proot_distro_installed; then
  echo "ERROR: proot distro '$PROOT_DISTRO' not installed. Run setup-proot-debian.sh first."
  exit 1
fi

echo "=== Phone Lab: setup RabbitMQ in proot ($PROOT_DISTRO) ==="

proot_run bash -s <<'INNER'
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

echo "[1/4] Installing rabbitmq-server..."
apt-get update -y
apt-get install -y rabbitmq-server

echo "[2/4] Writing rabbitmq.conf..."
mkdir -p /etc/rabbitmq
cat > /etc/rabbitmq/rabbitmq.conf <<'RMQCONF'
listeners.tcp.default = 5672
vm_memory_high_watermark.relative = 0.4
disk_free_limit.absolute = 256MB
RMQCONF
INNER

echo "[3/4] Starting RabbitMQ supervisor..."
bash "$SCRIPT_DIR/start-rabbit-proot.sh"

echo "[4/4] Creating RabbitMQ user..."
proot_run env RMQ_USER="$RMQ_USER" RMQ_PASS="$RMQ_PASS" bash -s <<'INNER'
set +e
rabbitmqctl await_startup >/dev/null 2>&1
rabbitmqctl add_user "$RMQ_USER" "$RMQ_PASS"
if [ $? -ne 0 ]; then
  rabbitmqctl change_password "$RMQ_USER" "$RMQ_PASS"
fi
rabbitmqctl set_user_tags "$RMQ_USER" administrator
rabbitmqctl set_permissions -p / "$RMQ_USER" '.*' '.*' '.*'
rabbitmqctl list_users
INNER

if rabbitmq_proot_ping; then
  echo "OK  rabbitmq-diagnostics ping (proot)"
else
  echo "ERROR: RabbitMQ not running in proot after setup"
  exit 1
fi

if amqp_port_open; then
  echo "OK  port ${RMQ_PORT} open from Termux"
else
  echo "WARN: port ${RMQ_PORT} not open from Termux (proot ping OK)"
fi

echo "=== RabbitMQ proot setup complete ==="
echo "  amqp://${RMQ_USER}:***@127.0.0.1:${RMQ_PORT}"
