#!/data/data/com.termux/files/usr/bin/bash
# Run rabbitmqctl inside proot Debian.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/proot-env.sh"

proot_run rabbitmqctl "$@"
