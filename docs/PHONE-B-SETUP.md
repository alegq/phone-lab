# phone-b setup playbook (phase 7)

Single checklist for **prod api-agents + PostgreSQL + RabbitMQ (proot)** on phone-b.  
Use when deploying a new phone-b or migrating from another device.

## Prerequisites

- [ ] Tailscale Connected on phone-b
- [ ] Termux installed, app opened after reboot (MIUI kills background)
- [ ] Charger plugged in, battery **Unrestricted**
- [ ] SSH from dev PC: `npm run remote:setup` once ([REMOTE-ACCESS.md](REMOTE-ACCESS.md))
- [ ] `mesh.env` has correct `PHONE_B_IP` and `PHONE_B_SSH_USER`

## Step 1 — Deploy package from dev PC

```powershell
cd C:\workspace\Ezrababait-2023\phone-lab
.\scripts\deploy-agents-prod.ps1
```

Send `agents-prod.tgz` to phone-b (Telegram or `ssh_upload`).

## Step 2 — Extract on phone-b

```bash
mkdir -p ~/phone-lab/packages/api-agents-prod
cd ~/phone-lab/packages/api-agents-prod
tar -xzf ~/storage/downloads/Telegram/agents-prod.tgz
npm install --omit=dev
cp .env.example .env
```

Ensure `.env` has:

```env
RABBIT_MQ_URI=amqp://rmuser:password123@127.0.0.1:5672
```

## Step 3 — Data plane (PostgreSQL + proot Rabbit)

**Option A — from dev PC (recommended):**

```powershell
npm run setup:phone-b-rabbit
```

**Option B — on phone-b Termux:**

```bash
bash scripts/termux/phone-b/setup-data-plane.sh
```

This installs PostgreSQL, proot Debian, and RabbitMQ 3.x. First proot install may take **20–40 minutes**.

Verify:

```bash
bash scripts/termux/phone-b/verify-rabbit-proot.sh
```

## Step 4 — Boot stack

```bash
bash scripts/termux/phone-b/boot-stack-phone-b.sh
bash scripts/termux/phone-b/install-boot-stack.sh
```

Local checks:

```bash
curl -s http://127.0.0.1:4010/public/api/agents/health/live
curl -s http://127.0.0.1:4010/public/api/agents/health/ready
bash scripts/termux/phone-b/verify-rabbit-proot.sh
```

## Step 5 — phone-a gateway (if new mesh)

Update gateway with prod ping mode and correct phone-b Tailscale IP. See [PHASE-7-DEPLOY.md](PHASE-7-DEPLOY.md) step 3.

## Step 6 — Verify from dev PC

```powershell
npm run smoke:gateway
$env:AGENTS_MODE="prod"; npm run smoke
npm run smoke:phase7
```

| Check | Expected |
|-------|----------|
| `smoke:gateway` | PASS |
| `AGENTS_MODE=prod npm run smoke` | S1 + S2 PASS |
| `smoke:phase7` | health/live + health/ready PASS; workflow completed |
| `smoke:phase8` | content bridge + allowlist + GSC + optional phase7 |

## Migrating to another phone-b

1. Update `mesh.env` (`PHONE_B_IP`, `PHONE_B_SSH_USER`)
2. `npm run remote:setup` for the new device
3. `.\scripts\deploy-agents-prod.ps1` + extract on new phone
4. Run this checklist from step 3
5. On phone-a: set `AGENTS_INTERNAL_URL` to new phone-b IP if changed

No api-agents rebuild unless application code changed.

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| SSH connection refused | Open Termux on phone-b; `bash scripts/termux/phone-b/start-sshd.sh` |
| `proot-distro install debian` slow | Wi-Fi; wait; PC script uses 60 min timeout |
| Port 5672 closed | `bash scripts/termux/phone-b/start-rabbit-proot.sh`; check `~/phone-lab/logs/rabbitmq-proot.log` |
| AMQP connection refused in agents log | `verify-rabbit-proot.sh`; restart agents |
| OOM / killed | Uninstall Termux `rabbitmq-server erlang`; close apps; charger |
| `set: invalid option name` in `.sh` | CRLF — redeploy with `deploy-agents-prod.ps1` or `npm run setup:phone-b-rabbit` |
| Never use `pkill -f rabbit` over SSH | Kills the SSH session; use `start-rabbit-proot.sh` / `reset-rabbit-proot.sh` |
| Rabbit fallback on PC | Docker `rabbitmq:3.13-management` on dev PC; `RABBIT_MQ_URI=@DEV_PC_IP:5672` — see [RABBITMQ-TERMUX.md](RABBITMQ-TERMUX.md) |

## Logs

| Service | Log |
|---------|-----|
| api-agents | `~/phone-lab/logs/agents-prod.log` |
| Rabbit (proot) | `~/phone-lab/logs/rabbitmq-proot.log` |
| PostgreSQL | `~/phone-lab/logs/postgres-phone-b.log` |
| Boot | `~/phone-lab/logs/boot-stack-phone-b.log` |

## Phase 10 — live Gemini (optional)

After phase 8 PASS:

```powershell
# mesh.secrets.env → GEMINI_API_KEY
npm run deploy:phone-b-phase10
# or:
.\scripts\apply-phone-b-env.ps1 -Profile live
.\scripts\remote-exec.ps1 phone-b "bash ~/phone-lab/packages/api-agents-prod/scripts/termux/phone-b/restart-agents-prod.sh"
npm run preflight:gemini
npm run smoke:phase10
```

Rollback: `.\scripts\apply-phone-b-env.ps1 -Profile stub`

See [PHASE-10-DEPLOY.md](PHASE-10-DEPLOY.md).

## See also

- [RABBITMQ-TERMUX.md](RABBITMQ-TERMUX.md)
- [PHASE-7-DEPLOY.md](PHASE-7-DEPLOY.md)
- [PHASE-10-DEPLOY.md](PHASE-10-DEPLOY.md)
