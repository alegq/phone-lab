#!/data/data/com.termux/files/usr/bin/bash
# One-time data plane for api-marketing fallback on phone-a (local PG + Redis).
set -euo pipefail

PGDATA="${PGDATA:-$HOME/phone-lab/data/postgres-marketing}"
DB_NAME="${DB_NAME:-marketing}"
DB_USER="${DB_USER:-admin}"
DB_PASS="${DB_PASS:-password123}"
LOG_DIR="${LOG_DIR:-$HOME/phone-lab/logs}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MKT_B="$HOME/phone-lab/packages/api-marketing-prod/scripts/termux/phone-b"

echo "=== Phone Lab phase 12: marketing data plane (phone-a fallback) ==="

pkg update -y
pkg install -y postgresql redis

mkdir -p "$HOME/phone-lab/data" "$LOG_DIR"

if [ ! -d "$PGDATA" ]; then
  initdb -D "$PGDATA" -U "$(whoami)" --locale=C --encoding=UTF8
fi

if ! pg_ctl -D "$PGDATA" status >/dev/null 2>&1; then
  pg_ctl -D "$PGDATA" -l "$LOG_DIR/postgres-marketing-phone-a.log" start
  sleep 2
fi

if ! psql -d postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='$DB_USER'" | grep -q 1; then
  psql -d postgres -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASS' SUPERUSER;"
fi
if ! psql -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='$DB_NAME'" | grep -q 1; then
  psql -d postgres -c "CREATE DATABASE $DB_NAME OWNER $DB_USER;"
fi

if [ -f "$MKT_B/start-redis.sh" ]; then
  bash "$MKT_B/start-redis.sh"
else
  bash "$SCRIPT_DIR/../phone-b/start-redis.sh" 2>/dev/null || redis-server --daemonize yes --port 6379 --bind 127.0.0.1
fi

echo "OK  phone-a marketing data plane: PGDATA=$PGDATA DB=$DB_NAME redis=127.0.0.1:6379"
