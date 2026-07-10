# Current Phone Lab architecture

> **Source of truth** for what is deployed on the mesh today.  
> Updated: 2026-07-10.

Deploy scripts write runtime routing to gitignored files:

| File | Written by | Meaning |
|------|------------|---------|
| `mesh.content.env` | `deploy-phase13.ps1` | `CONTENT_PHONE`, `CONTENT_IP`, `CONTENT_PORT` |
| `mesh.marketing.env` | `deploy-phase12.ps1` | `MARKETING_PHONE`, `MARKETING_IP`, `MARKETING_PORT` |
| `mesh.openclaw.env` | manual (from example) | `OPENCLAW_ENABLED`, tunnel, port for smoke |

---

## Deployed layout

```
dev-pc (100.98.162.107)
       ↓ Tailscale / smoke scripts
phone-a (100.120.187.10) — Xiaomi 14T, ~12 GB RAM
  api-gateway-prod      :4000
  api-content-prod      :4004   ← content host (Phase 13 fallback)
  openclaw gateway      :18789  ← Phase 14 lab (opt-in after onboard)
  cloudflared           (tunnel phone-a-gateway)
  PostgreSQL            (postgres-marketing — content/marketing data plane)
  Redis                 :6379

prod server (Linux)
  Ezrababait backend    (ezrababait.bufsa.com)
  openclaw gateway      :18789  ← Phase 14 lab (parallel spike, separate runbook)

phone-b (100.103.183.36) — Redmi Note 8T, ~4 GB RAM
  api-agents-prod       :4010
  api-auth-prod         :4001
  api-marketing-prod    :4008
  PostgreSQL            :5432   (agents, auth, marketing DBs)
  RabbitMQ (proot)      :5672
  Redis                 :6379
```

### Internal URLs (current)

| Consumer | Variable | Value |
|----------|----------|-------|
| gateway (phone-a) | `CONTENT_INTERNAL_URL` | `http://127.0.0.1:4004` |
| gateway (phone-a) | `MARKETING_INTERNAL_URL` | `http://100.103.183.36:4008` |
| agents (phone-b) | `CONTENT_INTERNAL_URL` | `http://100.120.187.10:4004` |

---

## Why content is on phone-a

Phase 13 **default target** is phone-b, but **auto mode falls back to phone-a** when phone-b OOM or health fails (same pattern as Phase 12 marketing).  
phone-b runs agents + auth + marketing + PG + Rabbit — adding full `api-content-prod` exceeds 4 GB RAM.

---

## Boot scripts

| Device | Termux:Boot | Starts |
|--------|-------------|--------|
| phone-a | `boot-gateway-phone-a.sh` | gateway-prod |
| phone-a | `start-content-phone-a.sh` | content-prod (if Phase 13 fallback) |
| phone-a | `boot-openclaw-phone-a.sh` | OpenClaw gateway (if `.openclaw-installed`) |
| phone-a | `start-crond.sh` | cron daemon (watchdog) |
| phone-b | `boot-stack-phone-b.sh` | PG → Rabbit → Redis → agents → auth → marketing (**skips content** when `mesh.content.env` has `CONTENT_PHONE=phone-a`) |
| phone-b | `start-crond.sh` | cron daemon (watchdog) |

**Watchdog:** cron `*/3 * * * *` runs `watch-stack-phone-{a,b}.sh` — health/live checks + restart with backoff. Deploy: `npm run deploy:watchdog`.

**Session start:** opening Termux after it was closed runs `session-start-phone-{a,b}.sh` via `~/.bashrc` hook. Deploy: `npm run deploy:session-start`. Use for nightly shutdown (close Termux) without full phone reboot.

---

## Content placement

| Target | When |
|--------|------|
| **phone-a :4004** | Default fallback — active when phone-b OOM risk |
| phone-b :4004 | Optional — only if `mesh.content.env` has `CONTENT_PHONE=phone-b` and RAM allows |

See [PHASE-13-DEPLOY.md](PHASE-13-DEPLOY.md) for deploy.  
Measure memory: `python scripts/remote/measure_rss.py`.

---

## OpenClaw (Phase 14 — lab layer)

**Not factory.** Experimental agent runtime for messenger/skills spikes. Factory remains `api-agents-prod` on phone-b.

| Instance | Host | Port | Deploy |
|----------|------|------|--------|
| openclaw-phone-a | phone-a Termux | `18789` | [PHASE-14-DEPLOY.md](PHASE-14-DEPLOY.md) |
| openclaw-server | prod Linux | `18789` | [OPENCLAW-SERVER-RUNBOOK.md](OPENCLAW-SERVER-RUNBOOK.md) |

**Forbidden:** OpenClaw on phone-b (OOM). Same Telegram bot token on two gateways.

Smoke: `npm run smoke:phase14` (requires `mesh.openclaw.env` + `OPENCLAW_ENABLED=1`).  
Architecture: [OPENCLAW-LAB.md](OPENCLAW-LAB.md).
