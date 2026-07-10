#!/data/data/com.termux/files/usr/bin/bash
# Phone Lab — Termux bootstrap (Phase 0)
# Run on both phone-a and phone-b:
#   bash scripts/termux/bootstrap.sh

set -euo pipefail

echo "=== Phone Lab Termux bootstrap ==="

export DEBIAN_FRONTEND=noninteractive

echo "[1/4] Updating package lists..."
pkg update -y

echo "[2/4] Upgrading installed packages..."
pkg upgrade -y

echo "[3/4] Installing nodejs-lts, git, curl..."
pkg install -y nodejs-lts git curl

echo "[4/4] Creating directories..."
mkdir -p ~/phone-lab/logs
mkdir -p ~/phone-lab/scripts/termux

NODE_VER="$(node --version 2>/dev/null || echo 'unknown')"
NODE_MAJOR="$(echo "$NODE_VER" | sed 's/^v//' | cut -d. -f1)"

echo ""
echo "=== Bootstrap complete ==="
echo "  node:    $NODE_VER"
echo "  git:     $(git --version 2>/dev/null || echo 'not found')"
echo "  logs:    ~/phone-lab/logs"
echo ""

if [ "$NODE_MAJOR" != "unknown" ] && [ "$NODE_MAJOR" -lt 18 ] 2>/dev/null; then
  echo "WARN: Node.js major version $NODE_MAJOR < 18. Phase 1+ requires Node 18+."
  echo "      Try: pkg upgrade && pkg install nodejs-lts"
  exit 1
fi

echo "Next steps:"
echo "  1. Ensure Tailscale is Connected on this phone"
echo "  2. On dev PC: fill mesh.env and run npm run verify:mesh"
echo "  3. Deploy prod stack — see docs/CURRENT-ARCHITECTURE.md"
