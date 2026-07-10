# Phase 10 — Live Agents Full Smoke (phone-b)

Enable **live Gemini** on phone-b prod `api-agents` and run `api-agents/scripts/smoke-local.mjs --full` against the phone mesh.

**Prerequisite:** Phase 7 + content deployed (`npm run smoke:phase8` PASS). Content is `api-content-prod` (Phase 13, typically on phone-a).

---

## Architecture

```
dev-pc
  smoke:phase10 → smoke-local.mjs --full
       ↓ Tailscale
phone-b (100.103.183.36)
  api-agents-prod     :4010  (LLM_STUB=false, live Gemini)
  PostgreSQL          :5432
  RabbitMQ (proot)    :5672

phone-a (100.120.187.10)
  api-content-prod    :4004  (agents reach via Tailscale)
```

See [CURRENT-ARCHITECTURE.md](CURRENT-ARCHITECTURE.md).

---

## What Phase 10 provides vs production

| Area | Phase 10 | Production |
|------|----------|------------|
| Agents code | same NestJS `dist/main.js` | Docker / GHCR |
| LLM | **live Gemini** from phone-b | live |
| GSC / SERP / crawl | **stub** (smoke-full design) | live |
| Content | **api-content-prod** | api-content + PostgreSQL |
| Acceptance | `smoke:phase10` PASS | `smoke:full` on server |

---

## Prerequisites

- [ ] `npm run smoke:phase8` PASS
- [ ] `mesh.env` + `mesh.secrets.env` on dev PC
- [ ] `GEMINI_API_KEY` in `mesh.secrets.env` (never commit)
- [ ] SSH to phone-b: `npm run remote:setup` once
- [ ] phone-b on **charger**, battery Unrestricted, ~4 GB RAM free

---

## Env profiles

| Profile | File | Use |
|---------|------|-----|
| stub (default) | `config/agents-prod.phone-b.env.stub.example` | `smoke:phase7/8` |
| live | `config/agents-prod.phone-b.env.live.example` | Phase 10, `smoke:phase10` |

Apply from dev PC:

```powershell
.\scripts\apply-phone-b-env.ps1 -Profile live   # phase 10
.\scripts\apply-phone-b-env.ps1 -Profile stub   # rollback
```

On phone-b (manual):

```bash
bash ~/phone-lab/packages/api-agents-prod/scripts/termux/phone-b/switch-agents-profile.sh live
```

---

## Step 1 — One-command deploy (recommended)

```powershell
cd C:\workspace\Ezrababait-2023\phone-lab
copy mesh.secrets.env.example mesh.secrets.env
# Edit mesh.secrets.env → GEMINI_API_KEY=...

npm run deploy:phone-b-phase10
```

This script:

1. Builds `agents-prod.tgz`
2. Uploads via SSH, `npm install` on phone-b
3. Applies live env profile
4. Runs `boot-stack-phone-b.sh`
5. Runs `preflight:gemini` + `smoke:phase10` (30–60 min)

Skip long smoke during deploy:

```powershell
.\scripts\deploy-phone-b-phase10.ps1 -SkipSmoke
```

Ensure content is deployed separately: `npm run deploy:phase13`

---

## Step 2 — Manual deploy

```powershell
.\scripts\deploy-agents-prod.ps1
python scripts\remote\ssh_upload.py phone-b agents-prod.tgz ~/agents-prod.tgz
.\scripts\apply-phone-b-env.ps1 -Profile live
.\scripts\remote-exec.ps1 phone-b "bash ~/phone-lab/packages/api-agents-prod/scripts/termux/phone-b/boot-stack-phone-b.sh"
```

---

## Step 3 — Verify

```powershell
npm run preflight:gemini
npm run smoke:phase10
npm run smoke:phase8
```

On phone-b:

```bash
bash ~/phone-lab/packages/api-agents-prod/scripts/termux/phone-b/test-gemini.sh
grep LLM_STUB ~/phone-lab/packages/api-agents-prod/.env
tail -30 ~/phone-lab/logs/agents-prod.log
```

---

## Rollback to stub profile

```powershell
.\scripts\apply-phone-b-env.ps1 -Profile stub
.\scripts\remote-exec.ps1 phone-b "bash ~/phone-lab/packages/api-agents-prod/scripts/termux/phone-b/restart-agents-prod.sh"
```

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `GEMINI_API_KEY required` | Set in `mesh.secrets.env`; run `apply-phone-b-env.ps1 -Profile live` |
| `LLM_STUB=true` in preflight | Re-apply live profile; restart agents |
| Gemini region / `FAILED_PRECONDITION` | Phone network blocks Gemini; try VPN or rollback stub |
| smoke-full timeout | Keep charger; close apps; re-run `smoke:phase10` |
| OOM / process killed | See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) § Phase 7 |
| `blog_template_images_only` fail | Redeploy content-prod: `npm run deploy:phase13` |

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) § Phase 10.

---

## See also

- [PHONE-B-SETUP.md](PHONE-B-SETUP.md)
- [PHASE-13-DEPLOY.md](PHASE-13-DEPLOY.md)
- [REMOTE-ACCESS.md](REMOTE-ACCESS.md)
