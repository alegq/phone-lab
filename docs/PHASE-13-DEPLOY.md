# Phase 13 — full api-content (phone-b or phone-a fallback)

Deploy prod **api-content** on port **4004**, with PostgreSQL `content` DB migrated from **k3s-dev**.

**Current deployment:** `api-content-prod` on **phone-a** (OOM fallback). See [CURRENT-ARCHITECTURE.md](CURRENT-ARCHITECTURE.md).

**Default deploy target:** phone-b (all services colocated). **Recommended for 4 GB phone-b:** deploy with `-Target phone-a` or let auto mode fall back.

**Prerequisites:** Phase 11–12 PASS, `mesh.env`, `mesh.secrets.env`, `api-content/.env` on dev PC, WSL kubectl (`k3s-dev`).

---

## Quick deploy

```powershell
cd C:\workspace\Ezrababait-2023\phone-lab
npm run deploy:phase13
```

This will:

1. Build `api-content` → `content-prod.tgz`
2. Rebuild `agents-prod.tgz` (boot stack prefers content-prod)
3. Deploy to phone-b, merge env (GCS secrets from `api-content/.env`)
4. Create `content` DB + migrate from k3s-dev
5. `npm install` on phone (ignore-scripts + sharp)
6. Start api-content-prod
7. Run `smoke:phase13` + regression phase11/12

### Force phone-a (OOM on phone-b)

```powershell
powershell -File scripts/deploy-phase13.ps1 -Target phone-a
# or after phone-b failure:
powershell -File scripts/deploy-phase13.ps1 -Target phone-a -SkipBuild
```

Auto mode tries phone-b first, then falls back to phone-a (like Phase 12 marketing).

```powershell
powershell -File scripts/deploy-phase13.ps1 -SkipMigrate
```

### Migrate DB only

```powershell
npm run migrate:content-db
```

---

## Architecture

### Current (content on phone-a — OOM fallback)

```
phone-a (100.120.187.10)
  api-gateway-prod      :4000
  api-content-prod      :4004
  PostgreSQL + Redis    (content data plane)

phone-b (100.103.183.36)
  api-agents-prod       :4010  CONTENT_INTERNAL_URL=http://100.120.187.10:4004
  api-auth-prod         :4001
  api-marketing-prod    :4008
  PostgreSQL            :5432  (agents, auth, marketing — no content DB)
  RabbitMQ + Redis
```

Gateway `CONTENT_INTERNAL_URL`: `http://127.0.0.1:4004` (loopback — content colocated on phone-a).

Written to `mesh.content.env`: `CONTENT_PHONE=phone-a`.

### Default target (content on phone-b — tight on 4 GB RAM)

```
phone-b (100.103.183.36)
  api-content-prod    :4004  (NestJS, PostgreSQL content DB)
  api-agents-prod     :4010  CONTENT_INTERNAL_URL=http://127.0.0.1:4004
  api-auth-prod       :4001
  api-marketing-prod  :4008
  PostgreSQL          :5432  (agents, auth, marketing, content)
  RabbitMQ + Redis
```

Gateway `CONTENT_INTERNAL_URL`: `http://100.103.183.36:4004`.

---

## Acceptance (P13)

| ID | Check |
|----|-------|
| P13-1 | `GET :4004/public/api/content/health/ready` → 200 |
| P13-2 | `blog_posts` count > 0 after k3s-dev migration |
| P13-3 | Internal agent routes with `x-internal-service-token` → 200 |
| P13-4 | Only `api-content-prod` listening on :4004 |
| P13-5 | `npm run smoke:phase13` PASS |
| P13-6 | `smoke:phase11`, `smoke:phase12` — no regression |

---

## Manual verification (Termux)

```bash
curl -s http://127.0.0.1:4004/public/api/content/health/live
curl -s http://127.0.0.1:4004/public/api/content/health/ready
psql -U admin -d content -c 'SELECT COUNT(*) FROM blog_posts;'
tail -40 ~/phone-lab/logs/content-prod.log
pgrep -af api-content-prod
```

---

## OOM mitigation

| Symptom | Fix |
|---------|-----|
| content-prod killed at boot | Charger; close apps; `HEAP_MAX_SIZE=251658240` |
| Still OOM with 6 services | Move marketing to phone-a: `deploy-phase12.ps1 -Target phone-a -SkipBuild` |
| npm install Killed | Retry; ensure `--ignore-scripts` |

---

## Config files

| File | Purpose |
|------|---------|
| `config/content-prod.phone-b.env.example` | phone-b template |
| `config/content-prod.phone-a.env.example` | phone-a template |
| `scripts/migrate-content-db.ps1` | k3s-dev → phone pg_dump |

---

## Related docs

- [PHASE-12-DEPLOY.md](PHASE-12-DEPLOY.md) — marketing
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) — Phase 13 section
