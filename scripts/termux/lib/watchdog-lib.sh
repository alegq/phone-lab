#!/data/data/com.termux/files/usr/bin/bash
# Shared watchdog helpers for Phone Lab (phone-a / phone-b).
# Source: source "$HOME/phone-lab/scripts/termux/lib/watchdog-lib.sh"

WD_LOG_DIR="${WD_LOG_DIR:-$HOME/phone-lab/logs}"
WD_LOG_FILE="${WD_LOG_FILE:-$WD_LOG_DIR/watchdog.log}"
WD_STATE_DIR="${WD_STATE_DIR:-$HOME/phone-lab/data/watchdog}"
WD_MAX_RESTARTS="${WD_MAX_RESTARTS:-3}"
WD_BACKOFF_WINDOW_SEC="${WD_BACKOFF_WINDOW_SEC:-900}"

mkdir -p "$WD_LOG_DIR" "$WD_STATE_DIR"

wd_log() {
  echo "$(date -Iseconds) watchdog: $*" >> "$WD_LOG_FILE"
}

wd_pkg_exists() {
  local name="$1"
  [ -d "$HOME/phone-lab/packages/$name" ]
}

wd_check_http() {
  local url="$1"
  curl -sf -m 10 "$url" >/dev/null 2>&1
}

wd_check_postgres() {
  local pgdata="$1"
  [ -d "$pgdata" ] && pg_ctl -D "$pgdata" status >/dev/null 2>&1
}

wd_check_redis() {
  if command -v redis-cli >/dev/null 2>&1; then
    redis-cli -a password123 ping 2>/dev/null | grep -q PONG
    return $?
  fi
  pgrep -x redis-server >/dev/null 2>&1
}

wd_check_rabbit() {
  local proot_env="$1"
  if [ ! -f "$proot_env" ]; then
    return 1
  fi
  # shellcheck disable=SC1090
  source "$proot_env"
  if amqp_port_open; then
    return 0
  fi
  timeout 20 rabbitmq_proot_ping
}

wd_state_file() {
  local service="$1"
  echo "$WD_STATE_DIR/${service}.state"
}

wd_should_restart() {
  local service="$1"
  local state_file
  local now count window_start last_restart
  state_file="$(wd_state_file "$service")"
  now="$(date +%s)"

  if [ ! -f "$state_file" ]; then
    return 0
  fi

  # shellcheck disable=SC1090
  source "$state_file"
  count="${RESTART_COUNT:-0}"
  window_start="${WINDOW_START:-0}"
  last_restart="${LAST_RESTART:-0}"

  if [ "$((now - window_start))" -ge "$WD_BACKOFF_WINDOW_SEC" ]; then
    return 0
  fi

  if [ "$count" -ge "$WD_MAX_RESTARTS" ]; then
    wd_log "WARN backoff skip $service ($count restarts in ${WD_BACKOFF_WINDOW_SEC}s window)"
    return 1
  fi

  return 0
}

wd_record_restart() {
  local service="$1"
  local state_file
  local now count window_start
  state_file="$(wd_state_file "$service")"
  now="$(date +%s)"
  count=1
  window_start="$now"

  if [ -f "$state_file" ]; then
    # shellcheck disable=SC1090
    source "$state_file"
    if [ "$((now - ${WINDOW_START:-0}))" -lt "$WD_BACKOFF_WINDOW_SEC" ]; then
      count=$(( ${RESTART_COUNT:-0} + 1 ))
      window_start="${WINDOW_START:-$now}"
    fi
  fi

  cat >"$state_file" <<EOF
RESTART_COUNT=$count
WINDOW_START=$window_start
LAST_RESTART=$now
EOF
}

wd_ensure_or_restart() {
  local service="$1"
  local check_cmd="$2"
  local restart_cmd="$3"

  if eval "$check_cmd"; then
    return 0
  fi

  wd_log "FAIL $service health check"
  if ! wd_should_restart "$service"; then
    return 1
  fi

  wd_log "restart $service"
  if eval "$restart_cmd"; then
    wd_record_restart "$service"
    local attempt
    for attempt in 1 2 3 4 5 6; do
      sleep 5
      if eval "$check_cmd"; then
        wd_log "OK $service recovered (attempt $attempt)"
        return 0
      fi
    done
    wd_log "WARN $service still unhealthy after restart"
    return 1
  fi

  wd_log "ERROR $service restart command failed"
  wd_record_restart "$service"
  return 1
}

wd_marketing_on_phone() {
  local phone="$1"
  if ! wd_pkg_exists "api-marketing-prod"; then
    return 1
  fi
  if [ -f "$HOME/phone-lab/mesh.marketing.env" ]; then
    # shellcheck disable=SC1091
    source "$HOME/phone-lab/mesh.marketing.env"
    [ "${MARKETING_PHONE:-phone-b}" = "$phone" ]
    return $?
  fi
  [ "$phone" = "phone-b" ]
}

wd_content_on_phone_b() {
  if ! wd_pkg_exists "api-content-prod"; then
    return 1
  fi
  if [ -f "$HOME/phone-lab/mesh.content.env" ]; then
    # shellcheck disable=SC1091
    source "$HOME/phone-lab/mesh.content.env"
    [ "${CONTENT_PHONE:-phone-b}" = "phone-b" ]
    return $?
  fi
  return 0
}

wd_phone_a_pgdata() {
  local marketing_pg="$HOME/phone-lab/data/postgres-marketing"
  local content_pg="$HOME/phone-lab/data/postgres-content"
  if [ -f "$HOME/phone-lab/mesh.content.env" ]; then
    # shellcheck disable=SC1091
    source "$HOME/phone-lab/mesh.content.env"
    if [ "${CONTENT_PHONE:-phone-b}" = "phone-a" ] && [ -d "$content_pg" ]; then
      echo "$content_pg"
      return
    fi
  fi
  if [ -d "$marketing_pg" ]; then
    echo "$marketing_pg"
  elif [ -d "$content_pg" ]; then
    echo "$content_pg"
  else
    echo ""
  fi
}
