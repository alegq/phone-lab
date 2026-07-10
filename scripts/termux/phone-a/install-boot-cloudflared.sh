set -euo pipefail

# Requires Termux:Boot app installed.

BOOT_DIR="$HOME/.termux/boot"
mkdir -p "$BOOT_DIR"

TARGET="$BOOT_DIR/start-cloudflared-phone-a.sh"

cat >"$TARGET" <<'EOF'
set -euo pipefail

# Give Android time to bring network/VPN up.
sleep 30

# If already running, do nothing.
if pgrep -f 'cloudflared tunnel run' >/dev/null 2>&1; then
  exit 0
fi

exec bash "$HOME/phone-lab/scripts/termux/phone-a/start-cloudflared-tunnel.sh"
EOF

chmod +x "$TARGET"
echo "Installed: $TARGET"
echo "Reboot phone-a and check: tail -50 ~/phone-lab/logs/cloudflared-phone-a.log"

