# Current Phone Lab architecture

> **Source of truth** for what is deployed on the mesh today.  
> Updated: 2026-07-10.

Deploy scripts write runtime routing to gitignored files:

| File | Written by | Meaning |
|------|------------|---------|
| `mesh.content.env` | `deploy-phase13.ps1` | `CONTENT_PHONE`, `CONTENT_IP`, `CONTENT_PORT` |
| `mesh.marketing.env` | `deploy-phase12.ps1` | `MARKETING_PHONE`, `MARKETING_IP`, `MARKETING_PORT` |

---

## Deployed layout

```
dev-pc (100.98.162.107)
       ↓ Tailscale / smoke scripts
phone-a (100.120.187.10) — Xiaomi 14T, ~12 GB RAM
  api-gateway-prod      :4000
  api-content-prod      :4004   ← content host (Phase 13 fallback)
  cloudflared           (tunnel phone-a-gateway)
  PostgreSQL            (postgres-marketing — content/marketing data plane)
  Redis                 :6379

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
| phone-a | `start-crond.sh` | cron daemon (watchdog) |
| phone-b | `boot-stack-phone-b.sh` | PG → Rabbit → Redis → agents → auth → marketing (**skips content** when `mesh.content.env` has `CONTENT_PHONE=phone-a`) |
| phone-b | `start-crond.sh` | cron daemon (watchdog) |

**Watchdog:** cron `*/3 * * * *` runs `watch-stack-phone-{a,b}.sh` — health/live checks + restart with backoff. Deploy: `npm run deploy:watchdog`.

---

## Content placement

| Target | When |
|--------|------|
| **phone-a :4004** | Default fallback — active when phone-b OOM risk |
| phone-b :4004 | Optional — only if `mesh.content.env` has `CONTENT_PHONE=phone-b` and RAM allows |

See [PHASE-13-DEPLOY.md](PHASE-13-DEPLOY.md) for deploy.  
Measure memory: `python scripts/remote/measure_rss.py`.
