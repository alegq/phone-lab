#!/data/data/com.termux/files/usr/bin/bash
# Pull-deploy api-agents-prod from GitHub Release (phone-b).
# Opt-in: set PULL_DEPLOY_AGENTS_ENABLED=1 in ~/phone-lab/pull-deploy.env
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIB="$HOME/phone-lab/scripts/termux/lib/pull-deploy-lib.sh"
if [ ! -f "$LIB" ] && [ -f "$SCRIPT_DIR/../lib/pull-deploy-lib.sh" ]; then
  LIB="$SCRIPT_DIR/../lib/pull-deploy-lib.sh"
fi
if [ ! -f "$LIB" ]; then
  echo "ERROR: pull-deploy-lib.sh not found — run deploy:pull-deploy from dev PC"
  exit 1
fi
# shellcheck source=/dev/null
source "$LIB"

DRY_RUN=0
SYNC_STATE=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --sync-state) SYNC_STATE=1 ;;
    -h|--help)
      echo "Usage: $0 [--dry-run] [--sync-state]"
      echo "  --dry-run     show what would be deployed"
      echo "  --sync-state  mark local .phone-lab-release as current (after manual deploy)"
      exit 0
      ;;
  esac
done

export GITHUB_REPO="${GITHUB_REPO:-Ezrababait-2023/api-agents}"
export RELEASE_TAG_PREFIX="${RELEASE_TAG_PREFIX:-phone-lab-agents-prod/}"
export ASSET_NAME="${ASSET_NAME:-agents-prod.tgz}"
export PKG_DIR="${PKG_DIR:-$HOME/phone-lab/packages/api-agents-prod}"
export RESTART_SCRIPT="${RESTART_SCRIPT:-$PKG_DIR/scripts/termux/phone-b/restart-agents-prod.sh}"

exec 9>"$PD_LOCK_FILE"
if ! flock -n 9; then
  pd_log "skip — another pull-deploy is running"
  exit 0
fi

pd_run_pull_deploy \
  "api-agents-prod" \
  "PULL_DEPLOY_AGENTS_ENABLED" \
  "$GITHUB_REPO" \
  "$RELEASE_TAG_PREFIX" \
  "$ASSET_NAME" \
  "$PKG_DIR" \
  "$RESTART_SCRIPT" \
  "$DRY_RUN" \
  "$SYNC_STATE"
