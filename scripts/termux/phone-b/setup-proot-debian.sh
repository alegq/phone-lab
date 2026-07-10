#!/data/data/com.termux/files/usr/bin/bash
# One-time: install proot-distro and Debian rootfs on phone-b.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/proot-env.sh"

echo "=== Phone Lab: setup proot ($PROOT_DISTRO) ==="

if ! command -v proot-distro >/dev/null 2>&1; then
  echo "[1/2] Installing proot-distro..."
  pkg update -y
  pkg install -y proot-distro
else
  echo "[1/2] proot-distro already installed"
fi

if proot_distro_installed; then
  echo "[2/2] proot distro '$PROOT_DISTRO' already installed"
else
  echo "[2/2] Installing proot distro '$PROOT_DISTRO' (may take 20-40 min)..."
  proot-distro install "$PROOT_DISTRO"
fi

echo "=== proot ready: $PROOT_DISTRO ==="
