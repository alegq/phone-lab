#!/data/data/com.termux/files/usr/bin/bash
# DEPRECATED: Termux rabbitmq-server 4.3 crashes on Android (Horus/Khepri).
# RabbitMQ runs in proot Debian — see proot-env.sh and setup-rabbit-proot.sh.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/proot-env.sh"

echo "WARN: configure-rabbitmq-termux.sh is deprecated — RabbitMQ is configured in proot ($PROOT_DISTRO)" >&2
