#!/data/data/com.termux/files/usr/bin/bash
# Ensure PostgreSQL has auth DB for api-auth (phone-b).
set -euo pipefail

PGDATA="${PGDATA:-$HOME/phone-lab/data/postgres}"
DB_NAME="${DB_NAME:-auth}"
DB_USER="${DB_USER:-admin}"
DB_PASS="${DB_PASS:-password123}"
LOG_DIR="${LOG_DIR:-$HOME/phone-lab/logs}"

mkdir -p "$LOG_DIR"

if ! command -v psql >/dev/null 2>&1; then
  echo "ERROR: psql not found. Run setup-data-plane.sh first."
  exit 1
fi

if [ ! -d "$PGDATA" ]; then
  echo "ERROR: PGDATA not found at $PGDATA. Run setup-data-plane.sh first."
  exit 1
fi

echo "=== setup auth DB (phone-b) ==="

# Ensure Postgres is running
if ! pg_ctl -D "$PGDATA" status >/dev/null 2>&1; then
  echo "postgres not running; starting..."
  pg_ctl -D "$PGDATA" -l "$LOG_DIR/postgres-phone-b.log" start
  sleep 2
fi

# Ensure role exists (created by setup-data-plane.sh normally)
if ! psql -d postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='$DB_USER'" | grep -q 1; then
  psql -d postgres -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASS' SUPERUSER;"
fi

# Ensure DB exists
if ! psql -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='$DB_NAME'" | grep -q 1; then
  psql -d postgres -c "CREATE DATABASE $DB_NAME OWNER $DB_USER;"
  echo "created DB: $DB_NAME"
else
  echo "DB exists: $DB_NAME"
fi

echo "OK  auth DB ready: $DB_NAME"

