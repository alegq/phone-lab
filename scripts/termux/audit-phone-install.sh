#!/data/data/com.termux/files/usr/bin/bash
# Audit Phone Lab install on this device (run via SSH).
set -eu

PHONE_LABEL="${1:-phone}"
echo "========== Phone Lab audit: $PHONE_LABEL =========="
echo "host: $(hostname 2>/dev/null || echo unknown) @ $(date -Iseconds)"
echo

check_file() {
  local path="$1"
  local label="$2"
  if [ -f "$path" ]; then
    echo "OK   $label: $path"
  else
    echo "MISS $label: $path"
  fi
}

check_dir() {
  local path="$1"
  local label="$2"
  if [ -d "$path" ]; then
    echo "OK   $label: $path"
  else
    echo "MISS $label: $path"
  fi
}

check_http() {
  local url="$1"
  local label="$2"
  if curl -sf -m 10 "$url" >/dev/null 2>&1; then
    echo "OK   health $label"
  else
    echo "FAIL health $label ($url)"
  fi
}

echo "--- Termux:Boot hooks ---"
if [ -d "$HOME/.termux/boot" ]; then
  ls -1 "$HOME/.termux/boot" 2>/dev/null | while read -r f; do
    if [ -x "$HOME/.termux/boot/$f" ]; then
      echo "OK   boot hook: $f"
    else
      echo "WARN boot hook not executable: $f"
    fi
  done
else
  echo "MISS ~/.termux/boot"
fi

echo
echo "--- Watchdog ---"
check_file "$HOME/phone-lab/scripts/termux/lib/watchdog-lib.sh" "watchdog-lib"
check_file "$HOME/phone-lab/scripts/termux/phone-b/watch-stack-phone-b.sh" "watch-phone-b"
check_file "$HOME/phone-lab/scripts/termux/phone-a/watch-stack-phone-a.sh" "watch-phone-a"
if command -v crond >/dev/null 2>&1; then
  if pgrep -x crond >/dev/null 2>&1; then
    echo "OK   crond running"
  else
    echo "WARN crond installed but not running"
  fi
else
  echo "MISS crond (cronie package)"
fi
if crontab -l 2>/dev/null | grep -q watch-stack; then
  echo "OK   watchdog crontab entry"
  crontab -l 2>/dev/null | grep watch-stack | sed 's/^/     /'
else
  echo "MISS watchdog crontab"
fi

echo
echo "--- Session start (Termux reopen) ---"
check_file "$HOME/phone-lab/scripts/termux/lib/session-start-lib.sh" "session-start-lib"
if [ "$PHONE_LABEL" = "phone-a" ]; then
  check_file "$HOME/phone-lab/scripts/termux/phone-a/session-start-phone-a.sh" "session-start-phone-a"
elif [ "$PHONE_LABEL" = "phone-b" ]; then
  check_file "$HOME/phone-lab/scripts/termux/phone-b/session-start-phone-b.sh" "session-start-phone-b"
fi
if grep -q 'phone-lab session-start' "$HOME/.bashrc" 2>/dev/null; then
  echo "OK   login hook in .bashrc"
else
  echo "MISS login hook in .bashrc (run deploy:session-start)"
fi
if [ -f "$HOME/phone-lab/logs/session-start.log" ]; then
  echo "--- Recent session-start log ---"
  tail -5 "$HOME/phone-lab/logs/session-start.log" | sed 's/^/     /'
fi

echo
echo "--- Mesh routing files ---"
check_file "$HOME/phone-lab/mesh.content.env" "mesh.content.env"
check_file "$HOME/phone-lab/mesh.marketing.env" "mesh.marketing.env"
if [ -f "$HOME/phone-lab/mesh.content.env" ]; then
  # shellcheck disable=SC1091
  source "$HOME/phone-lab/mesh.content.env"
  echo "     CONTENT_PHONE=${CONTENT_PHONE:-?}"
fi
if [ -f "$HOME/phone-lab/mesh.marketing.env" ]; then
  # shellcheck disable=SC1091
  source "$HOME/phone-lab/mesh.marketing.env"
  echo "     MARKETING_PHONE=${MARKETING_PHONE:-?}"
fi

echo
echo "--- Packages ---"
for pkg in api-gateway-prod api-content-prod api-agents-prod api-auth-prod api-marketing-prod; do
  check_dir "$HOME/phone-lab/packages/$pkg" "$pkg"
done

echo
echo "--- Processes (node by cwd) ---"
for pkg in api-gateway-prod api-content-prod api-agents-prod api-auth-prod api-marketing-prod; do
  found=""
  for p in $(pgrep -f 'node.*dist' 2>/dev/null || true); do
    c=$(readlink "/proc/$p/cwd" 2>/dev/null || true)
    case "$c" in *"$pkg"*) found="$p"; break;; esac
  done
  if [ -n "$found" ]; then
    echo "OK   process $pkg PID=$found"
  else
    echo "---- process $pkg (not running)"
  fi
done

echo
echo "--- Infrastructure ---"
if pg_ctl -D "$HOME/phone-lab/data/postgres" status >/dev/null 2>&1; then
  echo "OK   postgres (phone-b data)"
elif pg_ctl -D "$HOME/phone-lab/data/postgres-marketing" status >/dev/null 2>&1; then
  echo "OK   postgres-marketing (phone-a)"
elif pg_ctl -D "$HOME/phone-lab/data/postgres-content" status >/dev/null 2>&1; then
  echo "OK   postgres-content (phone-a)"
else
  echo "---- postgres not running"
fi

if timeout 5 bash -lc 'echo > /dev/tcp/127.0.0.1/5672' 2>/dev/null; then
  echo "OK   rabbit AMQP :5672"
else
  echo "---- rabbit :5672 (not open — expected on phone-b only)"
fi

if pgrep -x redis-server >/dev/null 2>&1; then
  echo "OK   redis"
else
  echo "---- redis (not running)"
fi

if pgrep -x sshd >/dev/null 2>&1; then
  echo "OK   sshd"
else
  echo "WARN sshd not running"
fi

echo
echo "--- Health endpoints (local) ---"
check_http "http://127.0.0.1:4000/api/health/live" "gateway:4000"
check_http "http://127.0.0.1:4004/public/api/content/health/live" "content:4004"
check_http "http://127.0.0.1:4001/public/api/auth/health/live" "auth:4001"
check_http "http://127.0.0.1:4008/api/health/live" "marketing:4008"
check_http "http://127.0.0.1:4010/public/api/agents/health/live" "agents:4010"

echo
echo "--- Recent watchdog log ---"
if [ -f "$HOME/phone-lab/logs/watchdog.log" ]; then
  tail -3 "$HOME/phone-lab/logs/watchdog.log" | sed 's/^/     /'
else
  echo "     (no watchdog.log)"
fi

echo "========== end audit: $PHONE_LABEL =========="
