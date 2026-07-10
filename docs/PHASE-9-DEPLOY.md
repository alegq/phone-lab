# Phase 9 — prod api-gateway on phone-a

Full NestJS **api-gateway** on phone-a port **4000**. Env points to phone-b agents/content/Rabbit.

**Prerequisite:** Phase 7 complete (`npm run smoke:phase7` PASS). Content via Phase 13 (`npm run smoke:phase8` PASS).

---

## Architecture

```
phone-a (100.120.187.10)
  api-gateway-prod    :4000
  api-content-prod    :4004   (Phase 13 — typically phone-a)

phone-b (100.103.183.36)
  api-agents-prod     :4010
  RabbitMQ (proot)    :5672
```

See [CURRENT-ARCHITECTURE.md](CURRENT-ARCHITECTURE.md) for live routing.

```mermaid
flowchart LR
  PC[dev PC] -->|smoke:gateway-prod| GW[phone-a :4000]
  PC -->|smoke:phase8| AG[phone-b :4010]
  GW -.-> AG
  GW -.-> CM[content :4004]
  GW -.-> RMQ[Rabbit]
```

---

## Acceptance (P9)

| ID | Check |
|----|-------|
| P9-1 | `GET .../api/health/startup` → 200 |
| P9-2 | `GET .../api/health/live` → `{ status: "alive" }` |
| P9-3 | `GET .../api/health/ready` → 200 (heap within `HEAP_MAX_SIZE`) |
| P9-4 | Port 4000 = prod gateway |
| P9-5 | `npm run smoke:gateway-prod` PASS from dev PC |
| P9-6 | `npm run smoke:phase8` PASS |

---

## Step 1 — Build on dev PC

```powershell
cd C:\workspace\Ezrababait-2023\phone-lab
.\scripts\deploy-gateway-prod.ps1
```

Creates `gateway-prod.tgz` (~dist + package.json; **no** Windows `node_modules`).

OAuth fields (`GOOGLE_CLIENT_*`, `FACEBOOK_CLIENT_*`) must be **non-empty** placeholders so Nest can bootstrap (OAuth routes inactive until real credentials).

---

## Step 2 — phone-a: deploy

**Via Telegram:** send `gateway-prod.tgz` to phone-a.

**Via SSH from PC:**

```powershell
python scripts\remote\ssh_upload.py phone-a gateway-prod.tgz gateway-prod.tgz
.\scripts\remote-exec.ps1 phone-a "mkdir -p ~/phone-lab/packages/api-gateway-prod && cd ~/phone-lab/packages/api-gateway-prod && tar -xzf ~/gateway-prod.tgz && cp -n .env.example .env 2>/dev/null || cp .env.example .env"
.\scripts\remote-exec.ps1 phone-a "cd ~/phone-lab/packages/api-gateway-prod && PUPPETEER_SKIP_DOWNLOAD=true npm install --omit=dev --legacy-peer-deps --ignore-scripts"
```

`npm install` on phone-a may take **10–20 minutes**. Keep charger connected.

---

## Step 3 — Optional: Rabbit cross-phone (phone-b)

If gateway logs show AMQP connection errors from phone-a:

```bash
# on phone-b
bash ~/phone-lab/packages/api-agents-prod/scripts/termux/phone-b/configure-rabbit-tailscale.sh
```

Or from PC:

```powershell
.\scripts\remote-exec.ps1 phone-b "bash ~/phone-lab/packages/api-agents-prod/scripts/termux/phone-b/configure-rabbit-tailscale.sh"
```

Health endpoints pass even if Rabbit is unreachable (`wait: false` at startup).

---

## Step 4 — Start prod gateway

```bash
bash ~/phone-lab/packages/api-gateway-prod/scripts/termux/phone-a/boot-gateway-phone-a.sh
```

Boot script: `sleep 30` → `fuser -k 4000/tcp` → `start-gateway-prod.sh` → `~/phone-lab/logs/gateway-prod.log`

**Termux:Boot (optional):**

```bash
bash scripts/termux/phone-a/install-boot-gateway.sh
```

---

## Step 5 — Smoke from dev PC

```powershell
npm run smoke:gateway-prod
npm run smoke:phase8
```

On phone-a:

```bash
curl -s http://127.0.0.1:4000/api/health/live
tail -30 ~/phone-lab/logs/gateway-prod.log
```

---

## Notes

- No demo HTML UI — use `/api/health/live` for health checks
- `NODE_ENV=development` + Tailscale origins in `.env` for browser CORS during lab
- Admin JWT routes via gateway require Phase 11 (`api-auth`)

See [DEVICE-REGISTRY.md](DEVICE-REGISTRY.md), [TROUBLESHOOTING.md](TROUBLESHOOTING.md).
