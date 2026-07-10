#!/data/data/com.termux/files/usr/bin/bash
# Shared pull-deploy helpers for Phone Lab (GitHub Release -> Termux package).
# Source: source "$HOME/phone-lab/scripts/termux/lib/pull-deploy-lib.sh"

PD_LOG_DIR="${PD_LOG_DIR:-$HOME/phone-lab/logs}"
PD_LOG_FILE="${PD_LOG_FILE:-$PD_LOG_DIR/pull-deploy.log}"
PD_DATA_DIR="${PD_DATA_DIR:-$HOME/phone-lab/data}"
PD_LOCK_FILE="${PD_LOCK_FILE:-$PD_DATA_DIR/pull-deploy.lock}"
PD_CONFIG_FILE="${PD_CONFIG_FILE:-$HOME/phone-lab/pull-deploy.env}"
PD_SECRETS_FILE="${PD_SECRETS_FILE:-$HOME/phone-lab/mesh.secrets.env}"

pd_log() {
  mkdir -p "$PD_LOG_DIR"
  echo "$(date -Iseconds) pull-deploy: $*" >> "$PD_LOG_FILE"
}

pd_load_env_file() {
  local file="$1"
  [ -f "$file" ] || return 0
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line//$'\r'/}"
    case "$line" in
      ''|\#*) continue ;;
    esac
    case "$line" in
      *=*)
        local key="${line%%=*}"
        local val="${line#*=}"
        key="$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
        val="$(echo "$val" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
        export "$key=$val"
        ;;
    esac
  done < "$file"
}

pd_load_config() {
  pd_load_env_file "$PD_CONFIG_FILE"
  pd_load_env_file "$PD_SECRETS_FILE"
}

pd_read_release_field() {
  local file="$1"
  local key="$2"
  local default="${3:-}"
  if [ ! -f "$file" ]; then
    echo "$default"
    return 0
  fi
  local val
  val="$(grep -E "^${key}=" "$file" 2>/dev/null | tail -1 | cut -d= -f2- | tr -d '\r')"
  if [ -n "$val" ]; then
    echo "$val"
  else
    echo "$default"
  fi
}

pd_local_sha() {
  local pkg_dir="$1"
  pd_read_release_field "$pkg_dir/.phone-lab-release" "SHA" ""
}

pd_state_file() {
  local service="${1:-api-agents-prod}"
  echo "$PD_DATA_DIR/pull-deploy-${service}.state"
}

pd_read_state() {
  local state_file="$1"
  local key="$2"
  pd_read_release_field "$state_file" "$key" ""
}

pd_write_state() {
  local state_file="$1"
  local sha="$2"
  local tag="$3"
  local source="${4:-github}"
  mkdir -p "$PD_DATA_DIR"
  cat >"$state_file" <<EOF
SHA=$sha
TAG=$tag
SOURCE=$source
APPLIED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF
}

pd_github_api() {
  local url="$1"
  local out="$2"
  local auth_args=()
  if [ -n "${GITHUB_TOKEN:-}" ]; then
    auth_args=(-H "Authorization: Bearer $GITHUB_TOKEN")
  fi
  curl -sfSL "${auth_args[@]}" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "$url" -o "$out"
}

pd_fetch_latest_release() {
  local repo="$1"
  local tag_prefix="$2"
  local out_json="$3"
  local page=1
  local tmp
  tmp="$(mktemp)"
  : >"$out_json"

  while [ "$page" -le 5 ]; do
    pd_github_api "https://api.github.com/repos/${repo}/releases?per_page=30&page=${page}" "$tmp" || return 1
    if [ ! -s "$tmp" ] || [ "$(cat "$tmp")" = "[]" ]; then
      rm -f "$tmp"
      return 1
    fi

    if command -v jq >/dev/null 2>&1; then
      if jq -e --arg p "$tag_prefix" '[.[] | select(.tag_name | startswith($p))] | .[0]' "$tmp" >"$out_json" 2>/dev/null; then
        if [ "$(jq -r '.tag_name // empty' "$out_json" 2>/dev/null)" != "" ]; then
          rm -f "$tmp"
          return 0
        fi
      fi
    else
      local tag
      tag="$(grep -o "\"tag_name\":[[:space:]]*\"${tag_prefix}[^\"]*\"" "$tmp" | head -1 | sed 's/.*"\([^"]*\)"$/\1/')"
      if [ -n "$tag" ]; then
        if command -v python >/dev/null 2>&1; then
          python - "$tmp" "$tag" >"$out_json" <<'PY'
import json, sys
data = json.load(open(sys.argv[1]))
tag = sys.argv[2]
for item in data:
    if item.get("tag_name") == tag:
        json.dump(item, sys.stdout)
        break
PY
        fi
        if [ -s "$out_json" ]; then
          rm -f "$tmp"
          return 0
        fi
      fi
    fi
    page=$((page + 1))
  done

  rm -f "$tmp"
  [ -s "$out_json" ]
}

pd_release_field() {
  local json="$1"
  local field="$2"
  if command -v jq >/dev/null 2>&1; then
    jq -r --arg f "$field" '.[$f] // empty' "$json"
  else
    case "$field" in
      tag_name)
        grep -o '"tag_name":[[:space:]]*"[^"]*"' "$json" | head -1 | sed 's/.*"\([^"]*\)"$/\1/'
        ;;
      id)
        grep -o '"id":[[:space:]]*[0-9]*' "$json" | head -1 | sed 's/[^0-9]*//'
        ;;
    esac
  fi
}

pd_find_asset_url() {
  local json="$1"
  local asset_name="$2"
  if command -v jq >/dev/null 2>&1; then
    jq -r --arg n "$asset_name" '.assets[] | select(.name == $n) | .url' "$json" | head -1
  else
    grep -o '"name":[[:space:]]*"'"$asset_name"'"' "$json" >/dev/null || return 1
    grep -o '"url":[[:space:]]*"[^"]*"' "$json" | head -1 | sed 's/.*"\([^"]*\)"$/\1/'
  fi
}

pd_download_asset() {
  local asset_api_url="$1"
  local dest="$2"
  local auth_args=()
  if [ -n "${GITHUB_TOKEN:-}" ]; then
    auth_args=(-H "Authorization: Bearer $GITHUB_TOKEN")
  fi
  curl -sfSL "${auth_args[@]}" \
    -H "Accept: application/octet-stream" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "$asset_api_url" -o "$dest"
}

pd_lockfile_hash() {
  local pkg_dir="$1"
  if [ -f "$pkg_dir/package-lock.json" ]; then
    if command -v sha256sum >/dev/null 2>&1; then
      sha256sum "$pkg_dir/package-lock.json" | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then
      shasum -a 256 "$pkg_dir/package-lock.json" | awk '{print $1}'
    else
      wc -c < "$pkg_dir/package-lock.json" | tr -d ' '
    fi
  else
    echo ""
  fi
}

pd_needs_update() {
  local pkg_dir="$1"
  local remote_tag="$2"
  local state_file="$3"
  local state_tag local_short remote_short local_sha

  state_tag="$(pd_read_state "$state_file" "TAG")"
  if [ -n "$remote_tag" ] && [ "$remote_tag" = "$state_tag" ]; then
    return 1
  fi

  remote_short="${remote_tag##*/}"
  local_short="$(pd_read_release_field "$pkg_dir/.phone-lab-release" "SHORT_SHA" "")"
  if [ -n "$local_short" ] && [ "$local_short" = "$remote_short" ]; then
    return 1
  fi

  local_sha="$(pd_local_sha "$pkg_dir")"
  if [ -n "$local_sha" ] && [ -n "$remote_short" ]; then
    if [ "$local_sha" = "$remote_short" ] || [ "${local_sha:0:7}" = "$remote_short" ]; then
      return 1
    fi
  fi

  return 0
}

pd_apply_tgz() {
  local tgz="$1"
  local pkg_dir="$2"
  mkdir -p "$pkg_dir"
  tar -xzf "$tgz" -C "$pkg_dir"
}

pd_maybe_npm_install() {
  local pkg_dir="$1"
  local state_file="$2"
  local new_hash prev_hash

  new_hash="$(pd_lockfile_hash "$pkg_dir")"
  prev_hash="$(pd_read_state "$state_file" "LOCK_SHA")"

  if [ -z "$new_hash" ]; then
    pd_log "skip npm install — no package-lock.json"
    return 0
  fi
  if [ "$new_hash" = "$prev_hash" ] && [ -d "$pkg_dir/node_modules" ]; then
    pd_log "skip npm install — lockfile unchanged"
    return 0
  fi

  pd_log "npm install --omit=dev (lock changed)"
  (cd "$pkg_dir" && npm install --omit=dev) || return 1
  mkdir -p "$PD_DATA_DIR"
  if grep -q '^LOCK_SHA=' "$state_file" 2>/dev/null; then
    sed -i "s/^LOCK_SHA=.*/LOCK_SHA=$new_hash/" "$state_file"
  else
    echo "LOCK_SHA=$new_hash" >>"$state_file"
  fi
}

pd_restart() {
  local restart_script="$1"
  if [ ! -f "$restart_script" ]; then
    pd_log "ERROR: restart script missing: $restart_script"
    return 1
  fi
  bash "$restart_script"
}

pd_sync_state_from_local() {
  local pkg_dir="$1"
  local state_file="$2"
  local local_sha tag

  local_sha="$(pd_local_sha "$pkg_dir")"
  tag="$(pd_read_release_field "$pkg_dir/.phone-lab-release" "TAG" "")"
  if [ -z "$tag" ]; then
    local short
    short="$(pd_read_release_field "$pkg_dir/.phone-lab-release" "SHORT_SHA" "")"
    if [ -n "$short" ]; then
      tag="manual/${short}"
    else
      tag="manual/$(date +%s)"
    fi
  fi
  if [ -z "$local_sha" ]; then
    pd_log "WARN: --sync-state but no local SHA in .phone-lab-release"
    return 1
  fi
  pd_write_state "$state_file" "$local_sha" "$tag" "manual"
  pd_log "synced state from local SHA=$local_sha tag=$tag"
}

pd_run_pull_deploy() {
  local service_name="$1"
  local enabled_var="$2"
  local repo="$3"
  local tag_prefix="$4"
  local asset_name="$5"
  local pkg_dir="$6"
  local restart_script="$7"
  local dry_run="${8:-0}"
  local sync_state="${9:-0}"

  pd_load_config

  local enabled="${!enabled_var:-0}"
  if [ "$enabled" != "1" ] && [ "$enabled" != "true" ] && [ "$enabled" != "yes" ]; then
    [ "$dry_run" = "1" ] && echo "pull-deploy disabled ($enabled_var=$enabled)"
    exit 0
  fi

  if [ -z "${GITHUB_TOKEN:-}" ]; then
    pd_log "ERROR: GITHUB_TOKEN missing in $PD_SECRETS_FILE"
    exit 1
  fi

  local state_file
  state_file="$(pd_state_file "$service_name")"

  if [ "$sync_state" = "1" ]; then
    pd_sync_state_from_local "$pkg_dir" "$state_file"
    exit $?
  fi

  if [ ! -d "$pkg_dir" ]; then
    pd_log "ERROR: package dir missing ($pkg_dir) — run manual deploy first"
    exit 1
  fi

  local release_json tag release_id asset_url remote_sha tmp_tgz
  release_json="$(mktemp)"
  tmp_tgz="$(mktemp)"

  if ! pd_fetch_latest_release "$repo" "$tag_prefix" "$release_json"; then
    pd_log "ERROR: no release found for $repo tag_prefix=$tag_prefix"
    rm -f "$release_json" "$tmp_tgz"
    exit 1
  fi

  tag="$(pd_release_field "$release_json" "tag_name")"
  release_id="$(pd_release_field "$release_json" "id")"
  asset_url="$(pd_find_asset_url "$release_json" "$asset_name")"

  if [ -z "$tag" ] || [ -z "$asset_url" ]; then
    pd_log "ERROR: release missing tag or asset $asset_name"
    rm -f "$release_json" "$tmp_tgz"
    exit 1
  fi

  if ! pd_needs_update "$pkg_dir" "$tag" "$state_file"; then
    [ "$dry_run" = "1" ] && echo "up to date: local/state matches $tag"
    rm -f "$release_json" "$tmp_tgz"
    exit 0
  fi

  if [ "$dry_run" = "1" ]; then
    echo "would deploy: $tag (release_id=$release_id) -> $pkg_dir"
    rm -f "$release_json" "$tmp_tgz"
    exit 0
  fi

  pd_log "deploying $tag -> $pkg_dir"
  if ! pd_download_asset "$asset_url" "$tmp_tgz"; then
    pd_log "ERROR: download failed for $asset_name"
    rm -f "$release_json" "$tmp_tgz"
    exit 1
  fi

  if ! pd_apply_tgz "$tmp_tgz" "$pkg_dir"; then
    pd_log "ERROR: tar extract failed"
    rm -f "$release_json" "$tmp_tgz"
    exit 1
  fi

  local applied_sha
  applied_sha="$(pd_local_sha "$pkg_dir")"
  if [ -z "$applied_sha" ]; then
    applied_sha="${tag##*/}"
  fi

  pd_write_state "$state_file" "$applied_sha" "$tag" "github"
  pd_maybe_npm_install "$pkg_dir" "$state_file" || {
    pd_log "ERROR: npm install failed"
    rm -f "$release_json" "$tmp_tgz"
    exit 1
  }

  if ! pd_restart "$restart_script"; then
    pd_log "ERROR: restart failed"
    rm -f "$release_json" "$tmp_tgz"
    exit 1
  fi

  pd_log "deployed $tag SHA=$applied_sha"
  rm -f "$release_json" "$tmp_tgz"
}
