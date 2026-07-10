#!/data/data/com.termux/files/usr/bin/bash
# Install api-marketing-prod boot script for Termux:Boot.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BOOT_DEST="$HOME/.termux/boot/start-marketing-phone-b.sh"

mkdir -p "$HOME/.termux/boot"
mkdir -p "$HOME/phone-lab/logs"

cat >"$BOOT_DEST" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
sleep 45
MKT="$HOME/phone-lab/packages/api-marketing-prod/scripts/termux/phone-b"
if [ -d "$MKT" ]; then
  bash "$MKT/start-redis.sh" || true
  bash "$MKT/restart-marketing-prod.sh" || true
fi
EOF

chmod +x "$BOOT_DEST"
echo "Installed: $BOOT_DEST"
