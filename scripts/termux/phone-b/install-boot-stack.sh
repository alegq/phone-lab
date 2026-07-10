#!/data/data/com.termux/files/usr/bin/bash
# Install phone-b full stack boot script for Termux:Boot.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BOOT_SRC="$SCRIPT_DIR/boot-stack-phone-b.sh"
BOOT_DEST="$HOME/.termux/boot/start-phone-b-stack.sh"

if [ ! -f "$BOOT_SRC" ]; then
  echo "ERROR: boot-stack-phone-b.sh not found at $BOOT_SRC"
  exit 1
fi

mkdir -p "$HOME/.termux/boot" "$HOME/phone-lab/logs"
cp "$BOOT_SRC" "$BOOT_DEST"
chmod +x "$BOOT_DEST"

echo "Installed: $BOOT_DEST"
echo "Starts full phone-b prod stack after reboot."
