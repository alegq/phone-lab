#!/data/data/com.termux/files/usr/bin/bash
# Install OpenClaw boot script for Termux:Boot (phone-a).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BOOT_SRC="$SCRIPT_DIR/boot-openclaw-phone-a.sh"
BOOT_DEST="$HOME/.termux/boot/start-openclaw-phone-a.sh"

if [ ! -f "$BOOT_SRC" ]; then
  echo "ERROR: boot-openclaw-phone-a.sh not found at $BOOT_SRC"
  exit 1
fi

mkdir -p "$HOME/.termux/boot"
mkdir -p "$HOME/phone-lab/logs"
cp "$BOOT_SRC" "$BOOT_DEST"
chmod +x "$BOOT_DEST"

echo "Installed: $BOOT_DEST"
echo "Requires: openclaw onboard completed + start-openclaw-phone-a.sh once"
echo "Verify from dev PC: npm run smoke:phase14"
