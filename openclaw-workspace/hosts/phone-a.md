# openclaw-phone-a host notes

- **Instance:** openclaw-phone-a (Termux, Xiaomi 14T)
- **Gateway:** `127.0.0.1:18789` default; mesh smoke via SSH tunnel or Tailscale bind
- **Telegram bot:** `ezra-lab-phone-a-*` — unique token, not shared with server
- **Workspace path:** `~/openclaw-workspace`
- **Install mode:** `native` or `proot` — see DEVICE-REGISTRY
- **Scripts:** `~/phone-lab/scripts/termux/phone-a/*openclaw*`
- **Deploy:** [docs/PHASE-14-DEPLOY.md](../docs/PHASE-14-DEPLOY.md)

Coexists with api-gateway-prod :4000 and api-content-prod :4004 — do not use those ports.
