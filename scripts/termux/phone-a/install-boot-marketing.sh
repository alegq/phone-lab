#!/data/data/com.termux/files/usr/bin/bash
# Install api-marketing-prod boot script for Termux:Boot (phone-a fallback).
set -euo pipefail

BOOT_DEST="$HOME/.termux/boot/start-marketing-phone-a.sh"

mkdir -p "$HOME/.termux/boot"
mkdir -p "$HOME/phone-lab/logs"

cat >"$BOOT_DEST" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
sleep 60
MKT="$HOME/phone-lab/packages/api-marketing-prod/scripts/termux/phone-b"
if [ -d "$MKT" ]; then
  bash "$HOME/phone-lab/packages/api-marketing-prod/scripts/termux/phone-a/setup-marketing-data-plane.sh" || true
  bash "$MKT/start-redis.sh" || true
  bash "$MKT/restart-marketing-prod.sh" || true
fi
EOF

chmod +x "$BOOT_DEST"
echo "Installed: $BOOT_DEST"
