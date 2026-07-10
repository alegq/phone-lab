#!/data/data/com.termux/files/usr/bin/bash
# Load OpenClaw phone-a env defaults.
set -euo pipefail

OPENCLAW_ENV="$HOME/phone-lab/openclaw-phone-a.env"
if [ -f "$OPENCLAW_ENV" ]; then
  # shellcheck disable=SC1090
  source "$OPENCLAW_ENV"
fi

export OPENCLAW_PORT="${OPENCLAW_PORT:-18789}"
export OPENCLAW_BIND="${OPENCLAW_BIND:-loopback}"
export OPENCLAW_TMUX_SESSION="${OPENCLAW_TMUX_SESSION:-oc}"
export OPENCLAW_INSTALL_MODE="${OPENCLAW_INSTALL_MODE:-native}"
export OPENCLAW_WORKSPACE="${OPENCLAW_WORKSPACE:-$HOME/openclaw-workspace}"

# Health URL for loopback bind modes (always 127.0.0.1 locally)
openclaw_health_url() {
  echo "http://127.0.0.1:${OPENCLAW_PORT}/health"
}

openclaw_cmd() {
  if [ "$OPENCLAW_INSTALL_MODE" = "proot" ]; then
    proot-distro login ubuntu -- bash -lc "export PATH=\"/usr/local/bin:\$PATH\"; openclaw $*"
  else
    openclaw "$@"
  fi
}

openclaw_gateway_cmd() {
  if [ "$OPENCLAW_INSTALL_MODE" = "proot" ]; then
    proot-distro login ubuntu -- bash -lc "export PATH=\"/usr/local/bin:\$PATH\"; openclaw gateway --port ${OPENCLAW_PORT} --bind ${OPENCLAW_BIND}"
  else
    openclaw gateway --port "${OPENCLAW_PORT}" --bind "${OPENCLAW_BIND}"
  fi
}
