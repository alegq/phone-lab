#!/data/data/com.termux/files/usr/bin/bash
# Start phone-a stack when Termux is opened after being closed (not only on device reboot).
set -euo pipefail

LOCK_FILE="$HOME/phone-lab/data/session-start.lock"
mkdir -p "$(dirname "$LOCK_FILE")"
exec 8>"$LOCK_FILE"
if ! flock -n 8; then
  exit 0
fi

WD_LIB="$HOME/phone-lab/scripts/termux/lib/watchdog-lib.sh"
SS_LIB="$HOME/phone-lab/scripts/termux/lib/session-start-lib.sh"
if [ ! -f "$WD_LIB" ] || [ ! -f "$SS_LIB" ]; then
  echo "ERROR: missing phone-lab scripts — run: npm run deploy:session-start"
  exit 1
fi
# shellcheck disable=SC1091
source "$WD_LIB"
# shellcheck disable=SC1091
source "$SS_LIB"

GW_DIR="$HOME/phone-lab/packages/api-gateway-prod/scripts/termux/phone-a"
CONTENT_SETUP="$HOME/phone-lab/packages/api-content-prod/scripts/termux/phone-a/setup-content-data-plane.sh"
CONTENT_SCRIPTS="$HOME/phone-lab/packages/api-content-prod/scripts/termux/phone-b"
GW_BOOT="$HOME/phone-lab/scripts/termux/phone-a/boot-gateway-phone-a.sh"
OC_RESTART="$HOME/phone-lab/scripts/termux/phone-a/restart-openclaw-phone-a.sh"
OC_OK=1

if [ -f "$HOME/phone-lab/.openclaw-installed" ] && [ -f "$OC_RESTART" ]; then
  if wd_check_http "http://127.0.0.1:18789/health"; then
    OC_OK=1
  else
    OC_OK=0
  fi
fi

ss_log "begin phone-a"
ss_ensure_crond
ss_ensure_sshd

PGDATA="$(wd_phone_a_pgdata)"
GATEWAY_OK=0
CONTENT_OK=0
PG_OK=0

if [ -z "$PGDATA" ] || wd_check_postgres "$PGDATA"; then
  PG_OK=1
fi
if ! wd_pkg_exists "api-gateway-prod" || wd_check_http "http://127.0.0.1:4000/api/health/live"; then
  GATEWAY_OK=1
fi
if ! wd_pkg_exists "api-content-prod" || wd_check_http "http://127.0.0.1:4004/public/api/content/health/live"; then
  CONTENT_OK=1
fi

if [ "$PG_OK" -eq 1 ] && [ "$GATEWAY_OK" -eq 1 ] && [ "$CONTENT_OK" -eq 1 ] && [ "$OC_OK" -eq 1 ]; then
  ss_log "OK phone-a stack already healthy"
  ss_wake_lock
  exit 0
fi

ss_log "starting phone-a stack (pg=$PG_OK gateway=$GATEWAY_OK content=$CONTENT_OK openclaw=$OC_OK)"

if [ -n "$PGDATA" ] && [ "$PG_OK" -eq 0 ] && [ -f "$CONTENT_SETUP" ]; then
  ss_log "start postgres (content data plane)"
  bash "$CONTENT_SETUP" || true
  sleep 2
fi

if [ "$GATEWAY_OK" -eq 0 ] && [ -f "$GW_BOOT" ]; then
  ss_log "start gateway"
  PHONE_LAB_BOOT_SLEEP=5 bash "$GW_BOOT" || true
elif [ "$GATEWAY_OK" -eq 0 ] && [ -d "$GW_DIR" ]; then
  ss_log "start gateway (restart script)"
  bash "$GW_DIR/restart-gateway-prod.sh" || true
fi

if [ "$CONTENT_OK" -eq 0 ] && [ -d "$CONTENT_SCRIPTS" ]; then
  ss_log "start content"
  bash "$CONTENT_SCRIPTS/restart-content-prod.sh" || true
fi

if [ "$OC_OK" -eq 0 ] && [ -f "$OC_RESTART" ]; then
  ss_log "start openclaw"
  bash "$OC_RESTART" || true
fi

ss_wake_lock
ss_log "done phone-a"
