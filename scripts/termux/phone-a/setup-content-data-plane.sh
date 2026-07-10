#!/data/data/com.termux/files/usr/bin/bash
# One-time data plane for api-content fallback on phone-a (reuse PG on :5432).
set -euo pipefail

MARKETING_PG="$HOME/phone-lab/data/postgres-marketing"
PGDATA="${PGDATA:-$HOME/phone-lab/data/postgres-content}"
DB_NAME="${DB_NAME:-content}"
DB_USER="${DB_USER:-admin}"
DB_PASS="${DB_PASS:-password123}"
LOG_DIR="${LOG_DIR:-$HOME/phone-lab/logs}"

echo "=== Phone Lab phase 13: content data plane (phone-a fallback) ==="

mkdir -p "$HOME/phone-lab/data" "$LOG_DIR"

if pg_ctl -D "$MARKETING_PG" status >/dev/null 2>&1; then
  echo "Reusing postgres-marketing cluster on :5432"
  PGDATA="$MARKETING_PG"
elif pg_ctl -D "$PGDATA" status >/dev/null 2>&1; then
  echo "postgres-content already running"
else
  pkg install -y postgresql
  if [ ! -d "$PGDATA" ]; then
    initdb -D "$PGDATA" -U "$(whoami)" --locale=C --encoding=UTF8
  fi
  if ! pg_ctl -D "$PGDATA" status >/dev/null 2>&1; then
    pg_ctl -D "$PGDATA" -l "$LOG_DIR/postgres-content-phone-a.log" start
    sleep 2
  fi
fi

if ! psql -d postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='$DB_USER'" | grep -q 1; then
  psql -d postgres -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASS' SUPERUSER;"
fi
if ! psql -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='$DB_NAME'" | grep -q 1; then
  psql -d postgres -c "CREATE DATABASE $DB_NAME OWNER $DB_USER;"
  echo "created DB: $DB_NAME"
else
  echo "DB exists: $DB_NAME"
fi

echo "OK  phone-a content data plane: PGDATA=$PGDATA DB=$DB_NAME"
