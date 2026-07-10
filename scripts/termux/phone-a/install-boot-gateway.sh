#!/data/data/com.termux/files/usr/bin/bash
# Install api-gateway-prod boot script for Termux:Boot (phone-a-gateway).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BOOT_SRC="$SCRIPT_DIR/boot-gateway-phone-a.sh"
BOOT_DEST="$HOME/.termux/boot/start-gateway-prod.sh"

if [ ! -f "$BOOT_SRC" ]; then
  echo "ERROR: boot-gateway-phone-a.sh not found at $BOOT_SRC"
  exit 1
fi

mkdir -p "$HOME/.termux/boot"
mkdir -p "$HOME/phone-lab/logs"
cp "$BOOT_SRC" "$BOOT_DEST"
chmod +x "$BOOT_DEST"

echo "Installed: $BOOT_DEST"
echo "Next: from dev PC run: npm run smoke:gateway-prod"
