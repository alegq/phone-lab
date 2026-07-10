#!/data/data/com.termux/files/usr/bin/bash
# Start OpenClaw gateway on phone-a in tmux (wake-lock, loopback bind).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_DIR="$HOME/phone-lab/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/openclaw-phone-a.log"

# shellcheck disable=SC1091
source "$SCRIPT_DIR/openclaw-env.sh"

if ! command -v openclaw >/dev/null 2>&1 && [ "$OPENCLAW_INSTALL_MODE" != "proot" ]; then
  echo "$(date -Iseconds) start-openclaw: openclaw not installed — run: npm install -g openclaw@latest && openclaw onboard" >> "$LOG_FILE"
  exit 1
fi

if ! command -v tmux >/dev/null 2>&1; then
  echo "$(date -Iseconds) start-openclaw: tmux missing — pkg install tmux" >> "$LOG_FILE"
  exit 1
fi

# Prevent Android sleep during start
if command -v termux-wake-lock >/dev/null 2>&1; then
  termux-wake-lock || true
fi

# Do not touch factory ports
fuser "${OPENCLAW_PORT}/tcp" 2>/dev/null || true

if tmux has-session -t "$OPENCLAW_TMUX_SESSION" 2>/dev/null; then
  if curl -sf -m 5 "$(openclaw_health_url)" >/dev/null 2>&1; then
    echo "$(date -Iseconds) start-openclaw: already running in tmux $OPENCLAW_TMUX_SESSION" >> "$LOG_FILE"
    touch "$HOME/phone-lab/.openclaw-installed"
    exit 0
  fi
  tmux kill-session -t "$OPENCLAW_TMUX_SESSION" 2>/dev/null || true
  sleep 1
fi

TMUX_CMD="openclaw gateway --port ${OPENCLAW_PORT} --bind ${OPENCLAW_BIND}"
if [ "$OPENCLAW_INSTALL_MODE" = "proot" ]; then
  TMUX_CMD="proot-distro login ubuntu -- bash -lc 'export PATH=/usr/local/bin:\$PATH; openclaw gateway --port ${OPENCLAW_PORT} --bind ${OPENCLAW_BIND}'"
fi

tmux new-session -d -s "$OPENCLAW_TMUX_SESSION" "$TMUX_CMD"
sleep 3

if curl -sf -m 15 "$(openclaw_health_url)" >/dev/null 2>&1; then
  echo "$(date -Iseconds) start-openclaw: gateway up :${OPENCLAW_PORT} mode=${OPENCLAW_INSTALL_MODE}" >> "$LOG_FILE"
  touch "$HOME/phone-lab/.openclaw-installed"
  exit 0
fi

echo "$(date -Iseconds) start-openclaw: health check failed — see tmux attach -t $OPENCLAW_TMUX_SESSION" >> "$LOG_FILE"
exit 1
