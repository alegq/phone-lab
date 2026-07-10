#!/data/data/com.termux/files/usr/bin/bash
# Install api-auth-prod boot script for Termux:Boot (phone-b).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BOOT_SRC="$SCRIPT_DIR/restart-auth-prod.sh"
BOOT_DEST="$HOME/.termux/boot/start-auth-prod.sh"

if [ ! -f "$BOOT_SRC" ]; then
  echo "ERROR: restart-auth-prod.sh not found at $BOOT_SRC"
  exit 1
fi

mkdir -p "$HOME/.termux/boot"
mkdir -p "$HOME/phone-lab/logs"
cp "$BOOT_SRC" "$BOOT_DEST"
chmod +x "$BOOT_DEST"

echo "Installed: $BOOT_DEST"

