#!/data/data/com.termux/files/usr/bin/bash
# Shared proot + RabbitMQ settings for phone-b phase 7.
# Source from other scripts: source "$(dirname "$0")/proot-env.sh"

PROOT_DISTRO="${PROOT_DISTRO:-debian}"
RMQ_USER="${RMQ_USER:-rmuser}"
RMQ_PASS="${RMQ_PASS:-password123}"
RMQ_PORT="${RMQ_PORT:-5672}"
LOG_DIR="${LOG_DIR:-$HOME/phone-lab/logs}"
RMQ_PROOT_LOG="$LOG_DIR/rabbitmq-proot.log"

proot_run() {
  proot-distro login "$PROOT_DISTRO" -- "$@"
}

proot_distro_installed() {
  proot-distro login "$PROOT_DISTRO" -- true >/dev/null 2>&1
}

rabbitmq_proot_ping() {
  timeout 15 proot-distro login "$PROOT_DISTRO" -- rabbitmq-diagnostics -q ping >/dev/null 2>&1
}

amqp_port_open() {
  (echo > /dev/tcp/127.0.0.1/"$RMQ_PORT") 2>/dev/null
}
