#!/data/data/com.termux/files/usr/bin/bash
# Install watchdog cron + crond boot hook on phone-b.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WATCH_SCRIPT="$HOME/phone-lab/scripts/termux/phone-b/watch-stack-phone-b.sh"
CRON_LINE="*/3 * * * * flock -n $HOME/phone-lab/data/watchdog.lock bash $WATCH_SCRIPT"
BOOT_CROND="$HOME/.termux/boot/start-crond.sh"

mkdir -p "$HOME/phone-lab/data/watchdog" "$HOME/phone-lab/logs" "$HOME/.termux/boot"
mkdir -p "$HOME/phone-lab/scripts/termux/lib" "$HOME/phone-lab/scripts/termux/phone-b"

if [ ! -f "$WATCH_SCRIPT" ]; then
  if [ -f "$SCRIPT_DIR/watch-stack-phone-b.sh" ]; then
    cp "$SCRIPT_DIR/watch-stack-phone-b.sh" "$WATCH_SCRIPT"
    chmod +x "$WATCH_SCRIPT"
  else
    echo "ERROR: $WATCH_SCRIPT not found — deploy watchdog scripts first"
    exit 1
  fi
fi

pkg install -y cronie util-linux

cat >"$BOOT_CROND" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
# Start cron daemon for phone-lab watchdog.
if command -v crond >/dev/null 2>&1; then
  pgrep -x crond >/dev/null 2>&1 || crond
fi
EOF
chmod +x "$BOOT_CROND"

TMP_CRON="$(mktemp)"
crontab -l 2>/dev/null | grep -v 'watch-stack-phone-b.sh' >"$TMP_CRON" || true
echo "$CRON_LINE" >>"$TMP_CRON"
crontab "$TMP_CRON"
rm -f "$TMP_CRON"

pgrep -x crond >/dev/null 2>&1 || crond

echo "Installed watchdog cron on phone-b:"
echo "  watch: $WATCH_SCRIPT"
echo "  crontab: $CRON_LINE"
echo "  boot: $BOOT_CROND"
echo ""
echo "Optional (keeps Termux awake, uses battery): termux-wake-lock"
echo "Logs: $HOME/phone-lab/logs/watchdog.log"
