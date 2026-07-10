#!/data/data/com.termux/files/usr/bin/bash
# Boot full phone-b stack: PG → Rabbit → Redis → (content if on phone-b) → agents → auth → marketing.
# Content on phone-a (Phase 13 fallback): skip content here — see mesh.content.env / CURRENT-ARCHITECTURE.md.
set -euo pipefail

STACK_DIR="$HOME/phone-lab/packages/api-agents-prod/scripts/termux/phone-b"
AUTH_DIR="$HOME/phone-lab/packages/api-auth-prod/scripts/termux/phone-b"
MKT_DIR="$HOME/phone-lab/packages/api-marketing-prod/scripts/termux/phone-b"
CONTENT_DIR="$HOME/phone-lab/packages/api-content-prod/scripts/termux/phone-b"
LOG_DIR="$HOME/phone-lab/logs"
mkdir -p "$LOG_DIR"

if [ ! -d "$STACK_DIR" ]; then
  echo "$(date -Iseconds) boot-stack: missing $STACK_DIR" >> "$LOG_DIR/boot-stack-phone-b.log"
  exit 1
fi

sleep "${PHONE_LAB_BOOT_SLEEP:-30}"

pkill -f "packages/api-agents-mob" 2>/dev/null || true
pkill -f "api-agents-mob" 2>/dev/null || true
pkill -f "api-content-mob" 2>/dev/null || true
fuser -k 4010/tcp 2>/dev/null || true
fuser -k 4004/tcp 2>/dev/null || true
fuser -k 4001/tcp 2>/dev/null || true
fuser -k 4008/tcp 2>/dev/null || true
sleep 2

bash "$STACK_DIR/start-postgres.sh"
sleep 2
bash "$STACK_DIR/start-rabbit-proot.sh"
sleep 3
if [ -d "$MKT_DIR" ]; then
  bash "$MKT_DIR/start-redis.sh" || true
fi
sleep 1
CONTENT_HOST="phone-b"
if [ -f "$HOME/phone-lab/mesh.content.env" ]; then
  # shellcheck disable=SC1091
  source "$HOME/phone-lab/mesh.content.env"
  CONTENT_HOST="${CONTENT_PHONE:-phone-b}"
fi
if [ "$CONTENT_HOST" = "phone-b" ]; then
  if [ -d "$CONTENT_DIR" ] && [ -f "$CONTENT_DIR/start-content-prod.sh" ]; then
    bash "$CONTENT_DIR/restart-content-prod.sh" || bash "$CONTENT_DIR/start-content-prod.sh"
  else
    echo "$(date -Iseconds) boot-stack: content-prod not deployed on phone-b" >> "$LOG_DIR/boot-stack-phone-b.log"
  fi
else
  echo "$(date -Iseconds) boot-stack: skip content (CONTENT_PHONE=$CONTENT_HOST)" >> "$LOG_DIR/boot-stack-phone-b.log"
fi
sleep 2
bash "$STACK_DIR/start-agents-prod.sh"
sleep 2
if [ -d "$AUTH_DIR" ]; then
  bash "$AUTH_DIR/restart-auth-prod.sh" || true
fi
sleep 2
if [ -d "$MKT_DIR" ]; then
  bash "$MKT_DIR/restart-marketing-prod.sh" || true
fi

echo "$(date -Iseconds) boot-stack-phone-b: done" >> "$LOG_DIR/boot-stack-phone-b.log"
