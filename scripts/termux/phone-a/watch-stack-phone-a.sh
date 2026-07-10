#!/data/data/com.termux/files/usr/bin/bash
# Watchdog: check phone-a stack and restart failed components.
set -euo pipefail

WD_LIB="$HOME/phone-lab/scripts/termux/lib/watchdog-lib.sh"
if [ ! -f "$WD_LIB" ]; then
  echo "ERROR: missing $WD_LIB — run deploy:watchdog from dev PC"
  exit 1
fi
# shellcheck disable=SC1091
source "$WD_LIB"

# Cron already wraps this script with flock on watchdog.lock — do not flock again here.
GW_DIR="$HOME/phone-lab/packages/api-gateway-prod/scripts/termux/phone-a"
CONTENT_SCRIPTS="$HOME/phone-lab/packages/api-content-prod/scripts/termux/phone-b"
MKT_DIR="$HOME/phone-lab/packages/api-marketing-prod/scripts/termux/phone-b"

wd_log "run phone-a stack check"
FAILURES=0

PGDATA="$(wd_phone_a_pgdata)"
if [ -n "$PGDATA" ]; then
  wd_ensure_or_restart "postgres-phone-a" \
    "wd_check_postgres '$PGDATA'" \
    "pg_ctl -D '$PGDATA' -l '$HOME/phone-lab/logs/postgres-phone-a-watchdog.log' start" || FAILURES=$((FAILURES + 1))
fi

if wd_marketing_on_phone "phone-a" && [ -d "$MKT_DIR" ]; then
  REDIS_SCRIPT="$MKT_DIR/start-redis.sh"
  if [ -f "$REDIS_SCRIPT" ]; then
    wd_ensure_or_restart "redis" \
      "wd_check_redis" \
      "bash '$REDIS_SCRIPT'" || FAILURES=$((FAILURES + 1))
  fi
fi

if wd_pkg_exists "api-gateway-prod" && [ -d "$GW_DIR" ]; then
  wd_ensure_or_restart "gateway" \
    "wd_check_http 'http://127.0.0.1:4000/api/health/live'" \
    "bash '$GW_DIR/restart-gateway-prod.sh'" || FAILURES=$((FAILURES + 1))
fi

if wd_pkg_exists "api-content-prod" && [ -d "$CONTENT_SCRIPTS" ]; then
  wd_ensure_or_restart "content" \
    "wd_check_http 'http://127.0.0.1:4004/public/api/content/health/live'" \
    "bash '$CONTENT_SCRIPTS/restart-content-prod.sh'" || FAILURES=$((FAILURES + 1))
fi

OC_RESTART="$HOME/phone-lab/scripts/termux/phone-a/restart-openclaw-phone-a.sh"
if [ -f "$HOME/phone-lab/.openclaw-installed" ] && [ -f "$OC_RESTART" ]; then
  wd_ensure_or_restart "openclaw" \
    "wd_check_http 'http://127.0.0.1:18789/health'" \
    "bash '$OC_RESTART'" || FAILURES=$((FAILURES + 1))
fi

if wd_marketing_on_phone "phone-a" && [ -d "$MKT_DIR" ]; then
  wd_ensure_or_restart "marketing" \
    "wd_check_http 'http://127.0.0.1:4008/api/health/live'" \
    "bash '$MKT_DIR/restart-marketing-prod.sh'" || FAILURES=$((FAILURES + 1))
fi

if [ "$FAILURES" -eq 0 ]; then
  wd_log "OK phone-a stack"
else
  wd_log "WARN phone-a stack $FAILURES component(s) unhealthy"
fi

exit "$FAILURES"
