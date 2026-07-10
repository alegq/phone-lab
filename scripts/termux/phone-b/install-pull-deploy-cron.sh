#!/data/data/com.termux/files/usr/bin/bash
# Install pull-deploy cron on phone-b (api-agents from GitHub Release).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PULL_SCRIPT="$HOME/phone-lab/scripts/termux/phone-b/pull-deploy-agents.sh"
LIB_SCRIPT="$HOME/phone-lab/scripts/termux/lib/pull-deploy-lib.sh"
CRON_LINE="*/5 * * * * flock -n $HOME/phone-lab/data/pull-deploy.lock bash $PULL_SCRIPT"

mkdir -p "$HOME/phone-lab/data" "$HOME/phone-lab/logs" "$HOME/phone-lab/scripts/termux/lib" "$HOME/phone-lab/scripts/termux/phone-b"

if [ -f "$SCRIPT_DIR/pull-deploy-agents.sh" ]; then
  cp "$SCRIPT_DIR/pull-deploy-agents.sh" "$PULL_SCRIPT"
  chmod +x "$PULL_SCRIPT"
fi
if [ -f "$SCRIPT_DIR/../lib/pull-deploy-lib.sh" ]; then
  cp "$SCRIPT_DIR/../lib/pull-deploy-lib.sh" "$LIB_SCRIPT"
  chmod +x "$LIB_SCRIPT"
fi

if [ ! -f "$PULL_SCRIPT" ] || [ ! -f "$LIB_SCRIPT" ]; then
  echo "ERROR: pull-deploy scripts missing — run npm run deploy:pull-deploy from dev PC"
  exit 1
fi

pkg install -y curl jq util-linux

if [ ! -f "$HOME/phone-lab/pull-deploy.env" ]; then
  if [ -f "$HOME/phone-lab/config/pull-deploy.env.example" ]; then
    cp "$HOME/phone-lab/config/pull-deploy.env.example" "$HOME/phone-lab/pull-deploy.env"
    echo "Created ~/phone-lab/pull-deploy.env from example — set PULL_DEPLOY_AGENTS_ENABLED=1"
  else
    cat >"$HOME/phone-lab/pull-deploy.env" <<'EOF'
# Pull-deploy config (phone-b)
PULL_DEPLOY_AGENTS_ENABLED=0
GITHUB_REPO=Ezrababait-2023/api-agents
RELEASE_TAG_PREFIX=phone-lab-agents-prod/
ASSET_NAME=agents-prod.tgz
EOF
    echo "Created ~/phone-lab/pull-deploy.env — set PULL_DEPLOY_AGENTS_ENABLED=1"
  fi
fi

if ! grep -q '^GITHUB_TOKEN=' "$HOME/phone-lab/mesh.secrets.env" 2>/dev/null; then
  echo "WARN: add GITHUB_TOKEN=... to ~/phone-lab/mesh.secrets.env (read-only PAT)"
fi

TMP_CRON="$(mktemp)"
crontab -l 2>/dev/null | grep -v 'pull-deploy-agents.sh' >"$TMP_CRON" || true
echo "$CRON_LINE" >>"$TMP_CRON"
crontab "$TMP_CRON"
rm -f "$TMP_CRON"

if ! pgrep -x crond >/dev/null 2>&1; then
  if [ -f "$HOME/.termux/boot/start-crond.sh" ]; then
    bash "$HOME/.termux/boot/start-crond.sh"
  elif command -v crond >/dev/null 2>&1; then
    crond
  fi
fi

echo "Installed pull-deploy cron on phone-b:"
echo "  script: $PULL_SCRIPT"
echo "  crontab: $CRON_LINE"
echo ""
echo "Enable: edit ~/phone-lab/pull-deploy.env → PULL_DEPLOY_AGENTS_ENABLED=1"
echo "Test:   bash $PULL_SCRIPT --dry-run"
echo "Logs:   tail -f ~/phone-lab/logs/pull-deploy.log"
