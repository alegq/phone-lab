#!/data/data/com.termux/files/usr/bin/bash
# Measure RSS per phone-lab process (run on phone via SSH).
set -eu

rss_kb() {
  local pid="$1"
  if [ -r "/proc/$pid/status" ]; then
    grep '^VmRSS:' "/proc/$pid/status" | awk '{print $2}'
  fi
}

print_node_pkg() {
  local pkg="$1"
  local pid cwd rss
  pid="$(pgrep -f "phone-lab/packages/${pkg}/" 2>/dev/null | head -1 || true)"
  if [ -z "$pid" ]; then
    pid="$(pgrep -f "${pkg}/dist" 2>/dev/null | head -1 || true)"
  fi
  if [ -n "$pid" ] && [ -r "/proc/$pid/cwd" ]; then
    cwd="$(readlink "/proc/$pid/cwd" 2>/dev/null || echo "?")"
    rss="$(rss_kb "$pid")"
    printf "%-22s PID=%-6s RSS=%6s KB (%4s MB)  %s\n" "$pkg" "$pid" "$rss" "$((rss / 1024))" "$cwd"
  else
    printf "%-22s (not running)\n" "$pkg"
  fi
}

print_proc() {
  local name="$1"
  local pattern="$2"
  local pid rss
  pid="$(pgrep -f "$pattern" 2>/dev/null | head -1 || true)"
  if [ -n "$pid" ]; then
    rss="$(rss_kb "$pid")"
    printf "%-22s PID=%-6s RSS=%6s KB (%4s MB)\n" "$name" "$pid" "$rss" "$((rss / 1024))"
  else
    printf "%-22s (not running)\n" "$name"
  fi
}

echo "=== $(hostname 2>/dev/null || echo phone) @ $(date -Iseconds) ==="
free -h | head -2
echo
echo "--- Node microservices ---"
for pkg in api-gateway-prod api-content-prod api-marketing-prod \
           api-agents-prod api-auth-prod; do
  print_node_pkg "$pkg"
done
echo
echo "--- Infrastructure ---"
print_proc "postgres-main" "postgres.*phone-lab/data/postgres[^-]"
print_proc "postgres-marketing" "postgres-marketing"
print_proc "redis" "redis-server"
print_proc "rabbitmq-beam" "beam.smp"
print_proc "proot-rabbit" "proot --kill-on-exit"
print_proc "cloudflared" "cloudflared tunnel"
echo
echo "--- Health ---"
curl -sf -m 3 http://127.0.0.1:4000/api/health/live >/dev/null 2>&1 && echo "gateway:4000 OK" || true
curl -sf -m 3 http://127.0.0.1:4004/api/health/live >/dev/null 2>&1 && echo "content:4004 OK" || true
curl -sf -m 3 http://127.0.0.1:4001/public/api/auth/health/live >/dev/null 2>&1 && echo "auth:4001 OK" || true
curl -sf -m 3 http://127.0.0.1:4008/api/health/live >/dev/null 2>&1 && echo "marketing:4008 OK" || true
curl -sf -m 3 http://127.0.0.1:4010/public/api/agents/health/live >/dev/null 2>&1 && echo "agents:4010 OK" || true
