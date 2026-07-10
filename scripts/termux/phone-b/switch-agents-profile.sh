#!/data/data/com.termux/files/usr/bin/bash
# Switch api-agents-prod env profile on phone-b (stub | live).
# Usage: bash switch-agents-profile.sh stub
#        bash switch-agents-profile.sh live
set -euo pipefail

PROFILE="${1:-}"
PKG_DIR="$HOME/phone-lab/packages/api-agents-prod"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ -z "$PROFILE" ] || { [ "$PROFILE" != "stub" ] && [ "$PROFILE" != "live" ]; }; then
  echo "Usage: $0 stub|live"
  exit 1
fi

TEMPLATE="$PKG_DIR/config/agents-prod.phone-b.env.${PROFILE}.example"
if [ ! -f "$TEMPLATE" ]; then
  TEMPLATE="$SCRIPT_DIR/../../config/agents-prod.phone-b.env.${PROFILE}.example"
fi
if [ ! -f "$TEMPLATE" ]; then
  TEMPLATE="$HOME/phone-lab/config/agents-prod.phone-b.env.${PROFILE}.example"
fi

if [ ! -f "$TEMPLATE" ]; then
  echo "ERROR: template not found for profile=$PROFILE"
  exit 1
fi

mkdir -p "$PKG_DIR"
cd "$PKG_DIR" || exit 1

if [ -f .env ]; then
  cp -f .env ".env.bak.$(date +%Y%m%d%H%M%S)"
fi

cp -f "$TEMPLATE" .env

# Inject GEMINI_API_KEY from mesh secrets if present on device
SECRETS="$HOME/phone-lab/mesh.secrets.env"
if [ -f "$SECRETS" ]; then
  # shellcheck disable=SC1090
  set -a
  source "$SECRETS"
  set +a
  if [ -n "${GEMINI_API_KEY:-}" ] && [ "$PROFILE" = "live" ]; then
    sed -i "s|^GEMINI_API_KEY=.*|GEMINI_API_KEY=${GEMINI_API_KEY}|" .env
  fi
  if [ -n "${INTERNAL_SERVICE_TOKEN:-}" ]; then
    sed -i "s|^INTERNAL_SERVICE_TOKEN=.*|INTERNAL_SERVICE_TOKEN=${INTERNAL_SERVICE_TOKEN}|" .env
    CONTENT_DIR="$HOME/phone-lab/packages/api-content-prod"
    if [ -f "$CONTENT_DIR/.env" ]; then
      sed -i "s|^INTERNAL_SERVICE_TOKEN=.*|INTERNAL_SERVICE_TOKEN=${INTERNAL_SERVICE_TOKEN}|" "$CONTENT_DIR/.env"
    fi
  fi
fi

echo "Switched api-agents-prod to profile=$PROFILE"

# Restart agents only (keep PG/Rabbit/content running)
pkill -f "$PKG_DIR/dist/main.js" 2>/dev/null || true
fuser -k 4010/tcp 2>/dev/null || true
sleep 2
bash "$SCRIPT_DIR/start-agents-prod.sh"
echo "agents-prod restarted with profile=$PROFILE"
