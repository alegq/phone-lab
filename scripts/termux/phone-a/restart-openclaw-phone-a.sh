#!/data/data/com.termux/files/usr/bin/bash
# Restart OpenClaw gateway on phone-a.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_DIR="$HOME/phone-lab/logs"
mkdir -p "$LOG_DIR"

# shellcheck disable=SC1091
source "$SCRIPT_DIR/openclaw-env.sh"

tmux kill-session -t "$OPENCLAW_TMUX_SESSION" 2>/dev/null || true
pkill -f "openclaw gateway" 2>/dev/null || true
fuser -k "${OPENCLAW_PORT}/tcp" 2>/dev/null || true
sleep 2

bash "$SCRIPT_DIR/start-openclaw-phone-a.sh"
echo "$(date -Iseconds) restart-openclaw-phone-a: done" >> "$LOG_DIR/openclaw-phone-a.log"
