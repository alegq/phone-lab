#!/data/data/com.termux/files/usr/bin/bash
# Helpers for Termux session start (after app reopen, not only device reboot).

SS_LOG_FILE="${SS_LOG_FILE:-$HOME/phone-lab/logs/session-start.log}"

mkdir -p "$(dirname "$SS_LOG_FILE")" "$HOME/phone-lab/data"

ss_log() {
  echo "$(date -Iseconds) session-start: $*" >>"$SS_LOG_FILE"
}

ss_ensure_crond() {
  if command -v crond >/dev/null 2>&1 && ! pgrep -x crond >/dev/null 2>&1; then
    crond
    ss_log "started crond"
  fi
}

ss_ensure_sshd() {
  if command -v sshd >/dev/null 2>&1 && ! pgrep -x sshd >/dev/null 2>&1; then
    sshd
    ss_log "started sshd"
  fi
}

ss_wake_lock() {
  if command -v termux-wake-lock >/dev/null 2>&1; then
    termux-wake-lock 2>/dev/null || true
    ss_log "termux-wake-lock (optional — keeps CPU awake while charging)"
  fi
}
