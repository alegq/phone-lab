# Phase 7 — prod api-agents on phone-b

Deploy **production NestJS `api-agents`** on phone-b.  
PostgreSQL + RabbitMQ run **on the same phone-b** (localhost).

**Current mesh:** see [CURRENT-ARCHITECTURE.md](CURRENT-ARCHITECTURE.md). Gateway is `api-gateway-prod` on phone-a (Phase 9).

---

## Architecture

```
phone-a (100.120.187.10)  api-gateway-prod :4000
    → Tailscale
phone-b (100.103.183.36)  api-agents-prod :4010
                          PostgreSQL        :5432 (127.0.0.1)
                          RabbitMQ          :5672 (proot Debian, 127.0.0.1)
```

---

## Prerequisites

- Phase 0 complete (`npm run verify:mesh`)
- phone-b: Termux, Node 18+, **on charger**, battery Unrestricted
- ~4 GB RAM minimum (tight — close other apps)
- Tailscale Connected on both phones

---

## Step 1 — Build on dev PC

```powershell
cd C:\workspace\Ezrababait-2023\phone-lab
.\scripts\deploy-agents-prod.ps1
```

Creates `agents-prod.tgz`. Send to phone-b (Telegram or SSH).

---

## Step 2 — phone-b: deploy prod stack

### 2.1 Extract agents-prod

```bash
mkdir -p ~/phone-lab/packages/api-agents-prod
cd ~/phone-lab/packages/api-agents-prod
tar -xzf ~/storage/downloads/Telegram/agents-prod.tgz
```

### 2.2 Install dependencies (on phone — required for native modules)

```bash
cd ~/phone-lab/packages/api-agents-prod
npm install --omit=dev
cp .env.example .env
```

This may take **10–20 minutes** on phone-b.

### 2.3 One-time data plane setup

```bash
bash scripts/termux/phone-b/setup-data-plane.sh
```

Installs PostgreSQL, proot Debian, and RabbitMQ 3.x; creates DB `agents` and user `rmuser`.

From dev PC (uploads scripts + full proot setup):

```powershell
npm run setup:phone-b-rabbit
```

See [PHONE-B-SETUP.md](PHONE-B-SETUP.md) and [RABBITMQ-TERMUX.md](RABBITMQ-TERMUX.md).

### 2.4 Start stack

```bash
bash scripts/termux/phone-b/boot-stack-phone-b.sh
```

Wait ~60s. Check logs:

```bash
tail -30 ~/phone-lab/logs/agents-prod.log
tail -10 ~/phone-lab/logs/postgres-phone-b.log
bash scripts/termux/phone-b/verify-rabbit-proot.sh
```

### 2.5 Optional: Termux boot

```bash
bash scripts/termux/phone-b/install-boot-stack.sh
```

After reboot (MIUI): Tailscale Connected → `bash ~/.termux/boot/start-phone-b-stack.sh` or wait for boot script.

### 2.6 Local verify on phone-b

```bash
curl -s http://127.0.0.1:4010/public/api/agents/health/live
curl -s http://127.0.0.1:4010/public/api/agents/health/ready
```

---

## Step 3 — Verify from dev PC

```powershell
cd C:\workspace\Ezrababait-2023\phone-lab
npm run smoke:phase7
npm run smoke
```

| Check | Command | Expected |
|-------|---------|----------|
| P7-1 | `smoke:phase7` | health/ready + workflow completed |
| P7-2 | `npm run smoke` | gateway + agents health PASS |

---

## Acceptance

- [ ] `health/ready` → 200 from phone-b Tailscale IP
- [ ] `test_durable_workflow` → `completed`
- [ ] `npm run smoke:phase7` PASS from dev PC

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `set: invalid option name` in `.sh` | Windows CRLF in archive — redeploy with latest `deploy-agents-prod.ps1`, or on phone: `sed -i 's/\r$//' scripts/termux/phone-b/*.sh` |
| `rabbitmq failed to start` | Use proot Rabbit: `bash scripts/termux/phone-b/setup-proot-debian.sh` then `setup-rabbit-proot.sh`; or `npm run setup:phone-b-rabbit` from PC |
| `EADDRINUSE :4010` | `pkill -f api-agents-prod`; `fuser -k 4010/tcp` |
| `health/ready` fails DB | `bash scripts/termux/phone-b/start-postgres.sh`; check `.env` DB_* |
| Rabbit connection error | `bash scripts/termux/phone-b/start-rabbit-proot.sh`; `verify-rabbit-proot.sh`; check `RABBIT_MQ_URI` |
| OOM / killed | Charger + close apps; reduce `HEAP_MAX_SIZE` |
| `npm install` fails on phone | Free storage; `pkg upgrade`; retry |
| Gateway 503 | agents not up; Tailscale down on phone-b |

---

## Next: Phase 9

Prod gateway on phone-a — [PHASE-9-DEPLOY.md](PHASE-9-DEPLOY.md).  
Content — [PHASE-13-DEPLOY.md](PHASE-13-DEPLOY.md).
