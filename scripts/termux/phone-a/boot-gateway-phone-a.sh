#!/data/data/com.termux/files/usr/bin/bash
# Boot prod api-gateway on phone-a.
set -euo pipefail

PKG_DIR="$HOME/phone-lab/packages/api-gateway-prod"
STACK_DIR="$PKG_DIR/scripts/termux/phone-a"
LOG_DIR="$HOME/phone-lab/logs"
mkdir -p "$LOG_DIR"

if [ ! -d "$STACK_DIR" ]; then
  echo "$(date -Iseconds) boot-gateway: missing $STACK_DIR" >> "$LOG_DIR/boot-gateway-phone-a.log"
  exit 1
fi

sleep "${PHONE_LAB_BOOT_SLEEP:-30}"

fuser -k 4000/tcp 2>/dev/null || true
sleep 3
fuser -k 4000/tcp 2>/dev/null || true

bash "$STACK_DIR/start-gateway-prod.sh"

echo "$(date -Iseconds) boot-gateway-phone-a: done" >> "$LOG_DIR/boot-gateway-phone-a.log"
