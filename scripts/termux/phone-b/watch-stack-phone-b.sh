#!/data/data/com.termux/files/usr/bin/bash
# Watchdog: check phone-b stack and restart failed components.
set -euo pipefail

WD_LIB="$HOME/phone-lab/scripts/termux/lib/watchdog-lib.sh"
if [ ! -f "$WD_LIB" ]; then
  echo "ERROR: missing $WD_LIB — run deploy:watchdog from dev PC"
  exit 1
fi
# shellcheck disable=SC1091
source "$WD_LIB"

LOCK_FILE="$HOME/phone-lab/data/watchdog.lock"
exec 9>"$LOCK_FILE"
if ! flock -n 9; then
  wd_log "skip phone-b (another watchdog run in progress)"
  exit 0
fi

STACK_DIR="$HOME/phone-lab/packages/api-agents-prod/scripts/termux/phone-b"
AUTH_DIR="$HOME/phone-lab/packages/api-auth-prod/scripts/termux/phone-b"
MKT_DIR="$HOME/phone-lab/packages/api-marketing-prod/scripts/termux/phone-b"
CONTENT_DIR="$HOME/phone-lab/packages/api-content-prod/scripts/termux/phone-b"

if [ ! -d "$STACK_DIR" ]; then
  wd_log "ERROR phone-b missing $STACK_DIR"
  exit 1
fi

wd_log "run phone-b stack check"
FAILURES=0

PGDATA="${PGDATA:-$HOME/phone-lab/data/postgres}"
if [ -d "$PGDATA" ]; then
  wd_ensure_or_restart "postgres" \
    "wd_check_postgres '$PGDATA'" \
    "bash '$STACK_DIR/start-postgres.sh'" || FAILURES=$((FAILURES + 1))
fi

PROOT_ENV="$STACK_DIR/proot-env.sh"
if [ -f "$PROOT_ENV" ]; then
  wd_ensure_or_restart "rabbit" \
    "wd_check_rabbit '$PROOT_ENV'" \
    "RABBITMQ_START_TIMEOUT=90 bash '$STACK_DIR/start-rabbit-proot.sh'" || FAILURES=$((FAILURES + 1))
fi

if [ -d "$MKT_DIR" ]; then
  wd_ensure_or_restart "redis" \
    "wd_check_redis" \
    "bash '$MKT_DIR/start-redis.sh'" || FAILURES=$((FAILURES + 1))
fi

if wd_pkg_exists "api-agents-prod"; then
  wd_ensure_or_restart "agents" \
    "wd_check_http 'http://127.0.0.1:4010/public/api/agents/health/live'" \
    "bash '$STACK_DIR/restart-agents-prod.sh'" || FAILURES=$((FAILURES + 1))
fi

if wd_pkg_exists "api-auth-prod" && [ -d "$AUTH_DIR" ]; then
  wd_ensure_or_restart "auth" \
    "wd_check_http 'http://127.0.0.1:4001/public/api/auth/health/live'" \
    "bash '$AUTH_DIR/restart-auth-prod.sh'" || FAILURES=$((FAILURES + 1))
fi

if wd_pkg_exists "api-marketing-prod" && [ -d "$MKT_DIR" ] && wd_marketing_on_phone "phone-b"; then
  wd_ensure_or_restart "marketing" \
    "wd_check_http 'http://127.0.0.1:4008/api/health/live'" \
    "bash '$MKT_DIR/restart-marketing-prod.sh'" || FAILURES=$((FAILURES + 1))
fi

if wd_content_on_phone_b && [ -d "$CONTENT_DIR" ]; then
  wd_ensure_or_restart "content" \
    "wd_check_http 'http://127.0.0.1:4004/public/api/content/health/live'" \
    "bash '$CONTENT_DIR/restart-content-prod.sh'" || FAILURES=$((FAILURES + 1))
fi

if [ "$FAILURES" -eq 0 ]; then
  wd_log "OK phone-b stack"
else
  wd_log "WARN phone-b stack $FAILURES component(s) unhealthy"
fi

exit "$FAILURES"
