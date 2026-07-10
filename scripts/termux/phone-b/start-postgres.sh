#!/data/data/com.termux/files/usr/bin/bash
# Start PostgreSQL for Phone Lab phase 7 (phone-b).
set -euo pipefail

PGDATA="${PGDATA:-$HOME/phone-lab/data/postgres}"
LOG_DIR="$HOME/phone-lab/logs"
mkdir -p "$LOG_DIR" "$(dirname "$PGDATA")"

if [ ! -d "$PGDATA" ]; then
  echo "ERROR: PGDATA not initialized. Run setup-data-plane.sh first."
  exit 1
fi

if pg_ctl -D "$PGDATA" status >/dev/null 2>&1; then
  echo "postgres: already running"
  exit 0
fi

pg_ctl -D "$PGDATA" -l "$LOG_DIR/postgres-phone-b.log" start
echo "postgres: started (PGDATA=$PGDATA)"
