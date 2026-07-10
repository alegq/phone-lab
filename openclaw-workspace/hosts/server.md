# openclaw-server host notes

- **Instance:** openclaw-server (prod Linux)
- **Gateway:** `127.0.0.1:18789` (or Tailscale if configured)
- **Telegram bot:** `ezra-lab-srv-*` — unique token, not shared with phone-a
- **Workspace path:** `~/openclaw-workspace`
- **Daemon:** `systemctl --user status openclaw-gateway`
- **Runbook:** [docs/OPENCLAW-SERVER-RUNBOOK.md](../docs/OPENCLAW-SERVER-RUNBOOK.md)

Secrets live in `~/.openclaw/` — never commit.
