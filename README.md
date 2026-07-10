# Phone Lab

R&D experiment: run production NestJS microservices on Android phones connected via Tailscale.

**Not production.** Lab mesh only — see [docs/CURRENT-ARCHITECTURE.md](docs/CURRENT-ARCHITECTURE.md) for the live layout.

## Architecture

```
dev-pc (Tailscale)
  → phone-a :4000  api-gateway-prod
                 :4004  api-content-prod
  → phone-b :4010  api-agents-prod
            :4001  api-auth-prod
            :4008  api-marketing-prod
            :5432  PostgreSQL, :5672 RabbitMQ, :6379 Redis
```

Full details: [docs/CURRENT-ARCHITECTURE.md](docs/CURRENT-ARCHITECTURE.md)

## Quick commands

```powershell
cd C:\workspace\Ezrababait-2023\phone-lab
npm run verify:mesh        # Tailscale mesh check
npm run demo:preflight     # mesh + prod smoke
npm run smoke              # gateway-prod + agents-prod health
npm run smoke:gateway-prod # phone-a gateway health
npm run smoke:phase7       # phone-b agents workflow
npm run smoke:phase8       # content bridge + agents
npm run smoke:phase10      # live Gemini smoke-full
npm run smoke:phase13      # content-prod regression
npm run preflight:gemini
```

## Deploy guides

| Phase | What | Guide |
|-------|------|-------|
| 0 | Tailscale mesh setup | [PHASE-0-SETUP.md](docs/PHASE-0-SETUP.md) |
| 7 | api-agents-prod on phone-b | [PHASE-7-DEPLOY.md](docs/PHASE-7-DEPLOY.md) |
| 9 | api-gateway-prod on phone-a | [PHASE-9-DEPLOY.md](docs/PHASE-9-DEPLOY.md) |
| 10 | live Gemini + smoke-full | [PHASE-10-DEPLOY.md](docs/PHASE-10-DEPLOY.md) |
| 11 | api-auth + admin JWT | [PHASE-11-DEPLOY.md](docs/PHASE-11-DEPLOY.md) |
| 12 | api-marketing | [PHASE-12-DEPLOY.md](docs/PHASE-12-DEPLOY.md) |
| 13 | api-content-prod | [PHASE-13-DEPLOY.md](docs/PHASE-13-DEPLOY.md) |

### Common deploy commands

```powershell
.\scripts\deploy-agents-prod.ps1
.\scripts\deploy-gateway-prod.ps1
npm run deploy:phase12
npm run deploy:phase13
npm run deploy:phone-b-phase10   # live Gemini on phone-b
npm run setup:phone-b-rabbit     # RabbitMQ in proot Debian
```

## Boot scripts (Termux:Boot)

| Device | Boot script | Log |
|--------|-------------|-----|
| phone-a | `boot-gateway-phone-a.sh` | `gateway-prod.log` |
| phone-a | `start-content-phone-a.sh` | `content-prod.log` |
| phone-b | `boot-stack-phone-b.sh` | `boot-stack-phone-b.log` |

Logs: `~/phone-lab/logs/`

## Remote Termux from PC (SSH)

One-time: `npm run remote:setup` (see [docs/REMOTE-ACCESS.md](docs/REMOTE-ACCESS.md)).

```powershell
.\scripts\remote-exec.ps1 phone-b "bash ~/phone-lab/packages/api-agents-prod/scripts/termux/phone-b/verify-rabbit-proot.sh"
```

## Troubleshooting

[docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)
