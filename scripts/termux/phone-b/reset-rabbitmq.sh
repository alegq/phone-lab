#!/data/data/com.termux/files/usr/bin/bash
# DEPRECATED: Termux RabbitMQ is broken. Reset proot Rabbit instead.
set -euo pipefail

echo "WARN: reset-rabbitmq.sh is deprecated — using reset-rabbit-proot.sh" >&2
exec bash "$(dirname "$0")/reset-rabbit-proot.sh"
