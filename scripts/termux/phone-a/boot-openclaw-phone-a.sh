#!/data/data/com.termux/files/usr/bin/bash
# Boot OpenClaw on phone-a (Termux:Boot). Does not touch gateway :4000 or content :4004.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_DIR="$HOME/phone-lab/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/boot-openclaw-phone-a.log"

if [ ! -f "$HOME/phone-lab/.openclaw-installed" ] && [ ! -f "$HOME/phone-lab/openclaw-phone-a.env" ]; then
  echo "$(date -Iseconds) boot-openclaw: skip (not installed)" >> "$LOG_FILE"
  exit 0
fi

if ! command -v openclaw >/dev/null 2>&1; then
  # shellcheck disable=SC1091
  source "$SCRIPT_DIR/openclaw-env.sh" 2>/dev/null || true
  if [ "${OPENCLAW_INSTALL_MODE:-native}" != "proot" ]; then
    echo "$(date -Iseconds) boot-openclaw: openclaw not in PATH" >> "$LOG_FILE"
    exit 0
  fi
fi

sleep "${PHONE_LAB_BOOT_SLEEP:-30}"

bash "$SCRIPT_DIR/start-openclaw-phone-a.sh" >> "$LOG_FILE" 2>&1 || true
echo "$(date -Iseconds) boot-openclaw-phone-a: done" >> "$LOG_FILE"
