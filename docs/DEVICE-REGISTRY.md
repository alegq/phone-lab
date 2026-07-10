# Device Registry — Phone Lab

> Updated 2026-07-09. **Current layout:** [CURRENT-ARCHITECTURE.md](CURRENT-ARCHITECTURE.md)

| Device | Role | MagicDNS | Tailscale IP | Termux | Node ver | Status |
|--------|------|----------|--------------|--------|----------|--------|
| phone-a-gateway (Xiaomi 14T) | **api-gateway prod** :4000 + **api-content-prod** :4004 (fallback) | `phone-a-gateway` | `100.120.187.10` | yes | v24.17.0 | phase 13 content fallback |
| phone-b-agents (Redmi Note 8T) | **api-agents** :4010 + **api-auth** :4001 + **api-marketing** :4008 + PG + Rabbit + Redis | `phone-b-agents` | `100.103.183.36` | yes | v24.17.0 | phase 13 (content on phone-a) |
| dev-pc | developer / build | `dev-pc` | `100.98.162.107` | n/a | — | `smoke:phase10` |

## Status values

- `pending` — not yet verified
- `online` — `npm run verify:mesh` passes for this device
- `offline` — unreachable; see [TROUBLESHOOTING.md](TROUBLESHOOTING.md)

## Notes

| Device | Model / OS | Wi‑Fi | Charging | Battery opt |
|--------|------------|-------|----------|-------------|
| phone-a-gateway | Xiaomi 14T / Android 13+ | | | Unrestricted; manual boot after reboot (MIUI); `boot-gateway-phone-a` |
| phone-b-agents | Redmi Note 8T / Android 11 | | | Unrestricted; manual boot; phase 7: `boot-stack-phone-b` |

## How to find Tailscale IP

**Windows (dev PC):**

```powershell
tailscale ip -4
```

**Android:** Tailscale app → tap device name → IP address, or [admin console](https://login.tailscale.com/admin/machines).
