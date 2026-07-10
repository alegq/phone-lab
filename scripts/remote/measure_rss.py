#!/usr/bin/env python3
"""Measure RSS per phone-lab microservice on phone-a / phone-b."""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "remote"))

from ssh_exec import connect  # noqa: E402
from mesh_config import phone_target  # noqa: E402

PACKAGES = [
    "api-gateway-prod",
    "api-content-prod",
    "api-marketing-prod",
    "api-gateway-mob",
    "api-agents-prod",
    "api-auth-prod",
    "api-content-mob",
]

INFRA = [
    ("postgres-main", "phone-lab/data/postgres$"),
    ("postgres-marketing", "postgres-marketing"),
    ("redis", "redis-server"),
    ("rabbitmq-beam", "beam.smp"),
    ("proot-rabbit", "proot --kill-on-exit"),
    ("cloudflared", "cloudflared tunnel"),
]

REMOTE_SCRIPT = r"""
free -h | head -2
echo '---NODE---'
for pid in $(pgrep -f 'node.*dist' 2>/dev/null); do
  [ -r /proc/$pid/cwd ] || continue
  cwd=$(readlink /proc/$pid/cwd 2>/dev/null || echo ?)
  case "$cwd" in
    *phone-lab/packages/*) pkg=$(echo "$cwd" | sed 's|.*/packages/||') ;;
    *) pkg=$(basename "$cwd") ;;
  esac
  rss=$(grep '^VmRSS:' /proc/$pid/status 2>/dev/null | awk '{print $2}')
  hwm=$(grep '^VmHWM:' /proc/$pid/status 2>/dev/null | awk '{print $2}')
  echo "NODE|$pkg|$pid|${rss:-0}|${hwm:-0}|$cwd"
done
echo '---INFRA---'
__INFRA_LINES__
echo '---HEALTH---'
curl -sf -m 3 http://127.0.0.1:4000/api/health/live >/dev/null && echo HEALTH|gateway:4000|ok
curl -sf -m 3 http://127.0.0.1:4004/api/health/live >/dev/null && echo HEALTH|content:4004|ok
curl -sf -m 3 http://127.0.0.1:4001/public/api/auth/health/live >/dev/null && echo HEALTH|auth:4001|ok
curl -sf -m 3 http://127.0.0.1:4008/api/health/live >/dev/null && echo HEALTH|marketing:4008|ok
curl -sf -m 3 http://127.0.0.1:4010/public/api/agents/health/live >/dev/null && echo HEALTH|agents:4010|ok
"""


def build_script() -> str:
    infra_lines = []
    for name, pattern in INFRA:
        infra_lines.append(
            f'pid=$(pgrep -f "{pattern}" 2>/dev/null | head -1); '
            f'if [ -n "$pid" ]; then rss=$(grep "^VmRSS:" /proc/$pid/status | awk \'{{print $2}}\'); hwm=$(grep "^VmHWM:" /proc/$pid/status | awk \'{{print $2}}\'); '
            f'echo "INFRA|{name}|$pid|$rss|$hwm"; else echo "INFRA|{name}|0|0|0"; fi'
        )
    return REMOTE_SCRIPT.replace("__INFRA_LINES__", "\n".join(infra_lines))


def run_phone(phone: str) -> str:
    target = phone_target(phone)
    client = connect(target, timeout=45)
    script = build_script()
    try:
        stdin, stdout, stderr = client.exec_command("bash -s", timeout=60)
        stdin.write(script)
        stdin.channel.shutdown_write()
        out = stdout.read().decode("utf-8", errors="replace")
        err = stderr.read().decode("utf-8", errors="replace")
        if err.strip():
            out += "\n" + err
        return out
    finally:
        client.close()


def format_report(phone: str, raw: str) -> str:
    lines = raw.strip().splitlines()
    mem = [l for l in lines if l.startswith("Mem:") or l.startswith("Swap:")]
    nodes = []
    infras = []
    health = []
    for line in lines:
        if line.startswith("NODE|"):
            parts = line.split("|")
            _, pkg, pid, rss, hwm, cwd = parts[0], parts[1], parts[2], parts[3], parts[4], parts[5] if len(parts) > 5 else ""
            nodes.append((pkg, pid, int(rss or 0), int(hwm or 0), cwd))
        elif line.startswith("INFRA|"):
            parts = line.split("|")
            _, name, pid, rss = parts[0], parts[1], parts[2], parts[3]
            hwm = int(parts[4]) if len(parts) > 4 else 0
            infras.append((name, pid, int(rss or 0), hwm))
        elif line.startswith("HEALTH|"):
            health.append(line.replace("HEALTH|", ""))

    running_nodes = [(p, pid, rss, hwm, cwd) for p, pid, rss, hwm, cwd in nodes if int(pid) > 0]
    running_infra = [(n, pid, rss, hwm) for n, pid, rss, hwm in infras if int(pid) > 0]
    node_total = sum(r for _, _, r, _, _ in running_nodes)
    infra_total = sum(r for _, _, r, _ in running_infra)

    out = [f"## {phone}", ""]
    if mem:
        out.extend(mem)
        out.append("")
    out.append("### Microservices (Node)")
    out.append("")
    out.append("| Service | PID | RSS now | Peak (VmHWM) |")
    out.append("|---------|-----|---------|--------------|")
    for pkg, pid, rss, hwm, cwd in sorted(nodes, key=lambda x: -max(x[2], x[3])):
        if int(pid) > 0 and rss >= 1024:
            out.append(f"| **{pkg}** | {pid} | {rss // 1024} MB | {hwm // 1024} MB |")
    out.append(f"| **Node total (RSS)** | | **{node_total // 1024} MB** | |")
    out.append("")
    out.append("### Infrastructure")
    out.append("")
    out.append("| Component | PID | RSS now | Peak |")
    out.append("|-----------|-----|---------|------|")
    for name, pid, rss, hwm in sorted(infras, key=lambda x: -max(x[2], x[3])):
        if int(pid) > 0:
            out.append(f"| {name} | {pid} | {rss // 1024} MB | {hwm // 1024} MB |")
        else:
            out.append(f"| {name} | - | not running | |")
    out.append(f"| **Infra total (RSS)** | | **{infra_total // 1024} MB** | |")
    out.append(f"| **Phone-lab total (RSS)** | | **{(node_total + infra_total) // 1024} MB** | |")
    if health:
        out.append("")
        out.append("### Health")
        for h in health:
            out.append(f"- {h}")
    return "\n".join(out)


def main() -> None:
    phones = sys.argv[1:] if len(sys.argv) > 1 else ["phone-a", "phone-b"]
    reports = []
    for phone in phones:
        print(f"Measuring {phone}...", file=sys.stderr)
        raw = run_phone(phone)
        reports.append(format_report(phone, raw))
    print("\n\n".join(reports))


if __name__ == "__main__":
    main()
