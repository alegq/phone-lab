#!/data/data/com.termux/files/usr/bin/bash
# Start phone-b stack when Termux is opened after being closed (not only on device reboot).
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

STACK_BOOT="$HOME/phone-lab/scripts/termux/phone-b/boot-stack-phone-b.sh"
STACK_DIR="$HOME/phone-lab/packages/api-agents-prod/scripts/termux/phone-b"

ss_log "begin phone-b"
ss_ensure_crond
ss_ensure_sshd

if [ ! -d "$STACK_DIR" ]; then
  ss_log "skip phone-b (api-agents-prod not deployed)"
  exit 0
fi

STACK_OK=1
if ! wd_check_http "http://127.0.0.1:4010/public/api/agents/health/live"; then
  STACK_OK=0
fi
if ! wd_check_http "http://127.0.0.1:4001/public/api/auth/health/live"; then
  STACK_OK=0
fi
if ! wd_check_http "http://127.0.0.1:4008/api/health/live"; then
  STACK_OK=0
fi

if [ "$STACK_OK" -eq 1 ]; then
  ss_log "OK phone-b stack already healthy"
  ss_wake_lock
  exit 0
fi

ss_log "starting phone-b stack"
if [ -f "$STACK_BOOT" ]; then
  PHONE_LAB_BOOT_SLEEP=5 bash "$STACK_BOOT" || true
else
  ss_log "ERROR missing $STACK_BOOT"
  exit 1
fi

ss_wake_lock
ss_log "done phone-b"
