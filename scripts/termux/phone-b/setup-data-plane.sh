#!/data/data/com.termux/files/usr/bin/bash
# One-time setup: PostgreSQL + RabbitMQ (proot Debian) for prod api-agents on phone-b.
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/proot-env.sh"

PGDATA="${PGDATA:-$HOME/phone-lab/data/postgres}"
DB_NAME="${DB_NAME:-agents}"
DB_USER="${DB_USER:-admin}"
DB_PASS="${DB_PASS:-password123}"

echo "=== Phone Lab phase 7: data plane setup (phone-b) ==="

echo "[1/6] Installing packages (postgresql + proot-distro)..."
pkg update -y
pkg install -y postgresql proot-distro

echo "[2/6] Initializing PostgreSQL..."
mkdir -p "$HOME/phone-lab/data" "$LOG_DIR"
if [ ! -d "$PGDATA" ]; then
  initdb -D "$PGDATA" -U "$(whoami)" --locale=C --encoding=UTF8
fi

bash "$SCRIPT_DIR/start-postgres.sh"
sleep 2

echo "[3/6] Creating database and user..."
if ! psql -d postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='$DB_USER'" | grep -q 1; then
  psql -d postgres -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASS' SUPERUSER;"
fi
if ! psql -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='$DB_NAME'" | grep -q 1; then
  psql -d postgres -c "CREATE DATABASE $DB_NAME OWNER $DB_USER;"
fi

echo "[4/6] Installing proot Debian..."
bash "$SCRIPT_DIR/setup-proot-debian.sh"

echo "[5/6] Setting up RabbitMQ in proot..."
bash "$SCRIPT_DIR/setup-rabbit-proot.sh"

echo "[6/6] Verifying RabbitMQ..."
bash "$SCRIPT_DIR/verify-rabbit-proot.sh"

echo ""
echo "=== Data plane ready ==="
echo "  PGDATA=$PGDATA"
echo "  DB: $DB_NAME / user $DB_USER"
echo "  RabbitMQ (proot): amqp://${RMQ_USER}:***@127.0.0.1:${RMQ_PORT}"
echo ""
echo "Optional: pkg uninstall rabbitmq-server erlang  # free RAM if old Termux pkg installed"
echo ""
echo "Next:"
echo "  cd ~/phone-lab/packages/api-agents-prod"
echo "  npm install --omit=dev && cp .env.example .env"
echo "  bash ~/phone-lab/packages/api-agents-prod/scripts/termux/phone-b/boot-stack-phone-b.sh"
