#!/data/data/com.termux/files/usr/bin/bash
# Bootstrap proot Ubuntu 22.04 + Node 22 + OpenClaw for phone-a (primary install path).
# Run in Termux: bash ~/phone-lab/scripts/termux/phone-a/install-openclaw-proot.sh
set -euo pipefail

LOG_DIR="$HOME/phone-lab/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/install-openclaw-proot.log"

echo "$(date -Iseconds) install-openclaw-proot: begin" >> "$LOG_FILE"

pkg update -y
pkg install -y proot-distro tmux curl git

if ! proot-distro list | grep -q "ubuntu"; then
  echo "Installing Ubuntu 22.04 in proot (one-time, may take several minutes)..."
  proot-distro install ubuntu
fi

echo "Setting up Node 22 + OpenClaw inside proot Ubuntu..."
proot-distro login ubuntu -- bash -lc '
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y curl ca-certificates git build-essential
if ! command -v node >/dev/null 2>&1 || [ "$(node -p "process.versions.node.split(\".\")[0]")" -lt 22 ]; then
  curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
  apt-get install -y nodejs
fi
npm install -g openclaw@latest
openclaw --version
'

ENV_FILE="$HOME/phone-lab/openclaw-phone-a.env"
if [ -f "$ENV_FILE" ]; then
  if grep -q '^OPENCLAW_INSTALL_MODE=' "$ENV_FILE"; then
    sed -i 's/^OPENCLAW_INSTALL_MODE=.*/OPENCLAW_INSTALL_MODE=proot/' "$ENV_FILE"
  else
    echo "OPENCLAW_INSTALL_MODE=proot" >> "$ENV_FILE"
  fi
else
  mkdir -p "$HOME/phone-lab"
  cp "$HOME/phone-lab/config/openclaw-phone-a.env.example" "$ENV_FILE" 2>/dev/null || true
  echo "OPENCLAW_INSTALL_MODE=proot" >> "$ENV_FILE"
fi

echo ""
echo "=== proot OpenClaw install complete ==="
echo "Next steps:"
echo "  1. proot-distro login ubuntu"
echo "  2. openclaw onboard"
echo "  3. exit"
echo "  4. bash ~/phone-lab/scripts/termux/phone-a/start-openclaw-phone-a.sh"
echo ""
echo "$(date -Iseconds) install-openclaw-proot: done" >> "$LOG_FILE"
