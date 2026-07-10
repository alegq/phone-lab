#!/data/data/com.termux/files/usr/bin/bash
# Kill a phone-lab Node service by package directory name (e.g. api-agents-prod).
set -eu
pkg_suffix="${1:?package suffix required}"
for p in $(pgrep -f 'node.*dist/main' 2>/dev/null); do
  c="$(readlink "/proc/$p/cwd" 2>/dev/null || true)"
  case "$c" in
    *"$pkg_suffix"*)
      kill "$p" 2>/dev/null || true
      exit 0
      ;;
  esac
done
exit 0
