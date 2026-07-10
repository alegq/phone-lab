#!/data/data/com.termux/files/usr/bin/bash
# Local health check for OpenClaw on phone-a.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/openclaw-env.sh"

URL="$(openclaw_health_url)"
echo "Checking $URL (bind=${OPENCLAW_BIND}, mode=${OPENCLAW_INSTALL_MODE})..."

if curl -sf -m 15 "$URL"; then
  echo ""
  echo "OK  openclaw health"
  exit 0
fi

echo ""
echo "FAIL  openclaw health — tmux attach -t ${OPENCLAW_TMUX_SESSION}"
exit 1
