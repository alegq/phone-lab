#!/data/data/com.termux/files/usr/bin/bash
# DEPRECATED: Termux rabbitmq-server 4.3 is broken on Android. Use start-rabbit-proot.sh.
set -euo pipefail

echo "WARN: start-rabbitmq.sh is deprecated — using proot RabbitMQ (start-rabbit-proot.sh)" >&2
exec bash "$(dirname "$0")/start-rabbit-proot.sh"
