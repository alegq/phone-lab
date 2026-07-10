# Troubleshooting — Phone Lab

Common issues. Current layout: [CURRENT-ARCHITECTURE.md](CURRENT-ARCHITECTURE.md).

---

## Mesh / Tailscale

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `verify:mesh` fails for phones | Tailscale not connected on phone | Open Tailscale app, ensure VPN is on |
| Ping fails, `tailscale ping` works | ICMP blocked on Android | Use `npm run verify:mesh` (tries both methods) |
| Wrong IP in mesh.env | Stale IP after reinstall | Re-check admin console or `tailscale ip -4` on device |
| MagicDNS vs numeric IP mismatch | Mixed hostname/IP in config | Pick one style; numeric `100.x` is most reliable |
| Phones on different Wi‑Fi / mobile data | Should still work via Tailscale | Ensure both show Connected in Tailscale app |
| Device not in admin console | Wrong account | Sign all devices into same Tailscale account |

---

## Termux

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `node: command not found` | Bootstrap not run | `bash scripts/termux/bootstrap.sh` |
| Node version < 18 | Old Termux packages | `pkg upgrade` then reinstall `nodejs-lts` |
| Process dies after screen off | Battery optimization | Unrestricted battery for Termux; use charger |
| Stack down after closing Termux | Android kills Termux processes | `npm run deploy:session-start` — auto-start on next Termux open |
| Boot script fails | Network not ready | Boot scripts include `sleep 30` at start |
| Service not up after reboot | Termux:Boot not installed | Install Termux:Boot from F-Droid; run `install-boot-stack.sh` |
| Duplicate node processes | Boot + manual start | Stop manual process; boot script uses `pgrep` guard |
| Empty `~/phone-lab/logs/*.log` | Boot script not run | `chmod +x ~/.termux/boot/*.sh`; reboot and wait 2 min |
| `pkg` errors | Outdated package lists | `pkg update && pkg upgrade` |

---

## HTTP services

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| Connection refused from PC | Server binds `127.0.0.1` only | Set `HOST=0.0.0.0` in `.env` |
| Works locally on phone, not from PC | Firewall or wrong bind | `curl 127.0.0.1:4010` on phone; check `0.0.0.0` |
| Gateway 503 upstream unavailable | Wrong internal URL in `.env` | Use phone **Tailscale IP**, not `localhost` from other device |
| Gateway 504 timeout | phone offline or slow mesh | Check Tailscale; increase fetch timeout in gateway `.env` |

---

## Phase 7 — prod api-agents on phone-b

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `health/ready` fails | PostgreSQL down | `bash scripts/termux/phone-b/start-postgres.sh` |
| Rabbit / AMQP errors | RabbitMQ not started | See [RABBITMQ-TERMUX.md](RABBITMQ-TERMUX.md) |
| Port 4010 in use | Stale process | `pkill -f api-agents-prod`; `fuser -k 4010/tcp` |
| Process killed (OOM) | 4 GB RAM limit | Charger; close apps; lower `HEAP_MAX_SIZE` |
| `npm install` on phone fails | Storage / arch | Free space; run on phone not Windows node_modules |

See [PHASE-7-DEPLOY.md](PHASE-7-DEPLOY.md).

---

## Phase 9 — prod api-gateway on phone-a

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| Port 4000 in use | Stale process | `fuser -k 4000/tcp`; run `boot-gateway-phone-a.sh` |
| Process killed (OOM) | Full NestJS ~800 MB+ RAM | Charger; close apps; `HEAP_MAX_SIZE=805306368` in `.env` |
| `npm install` fails on phone-a | peer deps / puppeteer on Android | `PUPPETEER_SKIP_DOWNLOAD=true npm install --omit=dev --legacy-peer-deps --ignore-scripts`; build only on PC |
| CORS error in browser | prod gateway strict origins | Set `NODE_ENV=development`; match `ALLOWED_ORIGIN_*` to your dev PC Tailscale IP |
| `GET /` 404 | Expected — no demo UI on prod gateway | Use `/api/health/live` |
| OAuth2Strategy requires clientID | Empty `GOOGLE_CLIENT_ID` in `.env` | Use non-empty placeholders in `gateway-prod.phone-a.env.example` |
| Admin routes 401 via gateway | api-auth not deployed | Use direct agents `http://PHONE_B_IP:4010/...` until phase 11 |
| Rabbit AMQP errors in log | Rabbit bound to 127.0.0.1 on phone-b | Run `configure-rabbit-tailscale.sh` on phone-b |

See [PHASE-9-DEPLOY.md](PHASE-9-DEPLOY.md).

---

## Phase 10 — live Gemini + smoke-full on phone-b

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `preflight:gemini` fails | `LLM_STUB=true` or empty key | `apply-phone-b-env.ps1 -Profile live`; check `mesh.secrets.env` |
| Gemini region error | API blocked from phone network | VPN on phone-b or rollback stub profile |
| `smoke:phase10` timeout | Blog workflows slow (30+ min) | Charger; re-run; close other apps |
| Workflow OOM | 4 GB RAM exhausted | Rollback stub; restart stack; see phase 7 OOM |
| `GEMINI_API_KEY required` on deploy | Missing secrets file | Copy `mesh.secrets.env.example` → `mesh.secrets.env` |
| smoke-full blog images fail | content-prod not deployed or stale seed | `npm run deploy:phase13`; check `content-prod.log` |

See [PHASE-10-DEPLOY.md](PHASE-10-DEPLOY.md).

---

## Phase 12 — api-marketing on phone-b (fallback phone-a)

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| Gateway 503 `Marketing unavailable` | Wrong `MARKETING_INTERNAL_URL` or stale gateway process | Set URL to `http://<marketing-tailscale-ip>:4008`; restart gateway-prod |
| `health/ready` fails on marketing | PostgreSQL or Redis down | `setup-marketing-db.sh` (phone-b) or `setup-marketing-data-plane.sh` (phone-a) |
| Process killed (OOM) on phone-b | 5 services on 4 GB RAM | Deploy fallback: `deploy-phase12.ps1 -Target phone-a` |
| `npm install` Killed | OOM during native deps | Retry on phone-a; use `--ignore-scripts` |
| Redis connection refused | redis-server not started | `bash scripts/termux/phone-b/start-redis.sh` |
| Port 4008 in use | Stale marketing process | `pkill -f api-marketing-prod`; `restart-marketing-prod.sh` |

See [PHASE-12-DEPLOY.md](PHASE-12-DEPLOY.md).

---

## Phase 13 — api-content-prod (phone-a fallback or phone-b)

See [CURRENT-ARCHITECTURE.md](CURRENT-ARCHITECTURE.md) for which host runs content today (`mesh.content.env`).

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `health/ready` fails | PostgreSQL down or heap over limit | `setup-content-db.sh`; check `HEAP_MAX_SIZE`; tail `content-prod.log` |
| `401 Invalid internal service token` | Token mismatch agents vs content | `apply-phone-b-env.ps1 -Profile live`; match `INTERNAL_SERVICE_TOKEN` |
| Port 4004 in use | Stale process | `pkill -f api-content-prod`; `restart-content-prod.sh` |
| Empty `published-posts` | Migration skipped or failed | `npm run migrate:content-db` |
| Joi boot error (GCS vars) | Missing secrets in merged `.env` | Ensure `api-content/.env` on PC; re-run `deploy:phase13` |
| `npm install` Killed | OOM | `--ignore-scripts`; move marketing to phone-a |
| Process killed (OOM) | 6 Node services on 4 GB | Marketing → phone-a; content → phone-a |
| `sharp` module error | Native build on ARM | `npm install sharp --omit=dev` on phone |
| Admin `/api/blogs/admin/*` → **503** | Gateway not restarted (old `CONTENT_INTERNAL_URL`) | Set `CONTENT_INTERNAL_URL=http://127.0.0.1:4004` when content on phone-a; `restart-gateway-prod.sh`; `npm run smoke:phase13` |

See [PHASE-13-DEPLOY.md](PHASE-13-DEPLOY.md).

---

## Diagnostic commands

**Windows (dev PC):**

```powershell
tailscale status
tailscale ping phone-a
npm run verify:mesh
npm run smoke
```

**Termux (on phone):**

```bash
termux-wake-lock
tail -f ~/phone-lab/logs/agents-prod.log
tail -f ~/phone-lab/logs/content-prod.log
tail -f ~/phone-lab/logs/gateway-prod.log
tail -f ~/phone-lab/logs/marketing-prod.log
bash ~/phone-lab/packages/api-agents-prod/scripts/termux/phone-b/test-gemini.sh
curl -v http://127.0.0.1:4000/api/health/live
curl -v http://127.0.0.1:4004/public/api/content/health/live
node --version
tail -f ~/phone-lab/logs/watchdog.log
```

---

## Watchdog (cron, every 3 min)

Deploy from dev PC: `npm run deploy:watchdog`. Verify: `npm run smoke:watchdog`.

| Symptom | Fix |
|---------|-----|
| Services die without reboot | Check `~/phone-lab/logs/watchdog.log`; run watchdog manually: `bash ~/phone-lab/scripts/termux/phone-b/watch-stack-phone-b.sh` |
| `backoff skip` in log | Service restarted 3× in 15 min (OOM loop protection) — free RAM, fix root cause, delete `~/phone-lab/data/watchdog/<service>.state` |
| Cron not running | `pgrep -x crond`; `crontab -l`; re-run `install-watchdog-cron.sh` |
| Disable watchdog | `crontab -l \| grep -v watch-stack \| crontab -` |

Scripts live in `~/phone-lab/scripts/termux/` (not inside service packages). Boot hook: `~/.termux/boot/start-crond.sh`.

---

## Session start (after closing Termux)

Deploy from dev PC: `npm run deploy:session-start`. Installs a hook in `~/.bashrc` and `~/.profile`.

| Symptom | Fix |
|---------|-----|
| Nothing starts when opening Termux | Re-run `npm run deploy:session-start`; open a new Termux session (not just switch apps) |
| Stack starts but slow | Normal — `session-start.log` shows progress; wait ~1–2 min |
| Hook runs on every new shell tab | Should not — `flock` on `~/phone-lab/data/session-start.lock` runs once per Termux process |
| Disable auto-start | Remove block between `# >>> phone-lab session-start >>>` and `# <<<` in `.bashrc` |

Log: `~/phone-lab/logs/session-start.log`. Nightly: close Termux, morning open Termux + Tailscale — stack starts in background.

---

## Phase 14 — OpenClaw

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `smoke:phase14` SKIP | `OPENCLAW_ENABLED` not set | Copy `mesh.openclaw.env.example` → `mesh.openclaw.env`, set `OPENCLAW_ENABLED=1` |
| Health fails from dev-pc, OK on phone | Gateway bind loopback | Set `OPENCLAW_SSH_TUNNEL=1` or SSH `-L 18789:127.0.0.1:18789` |
| Gateway crash on `lan`/`tailnet` bind | Auth required for non-loopback | Use `OPENCLAW_BIND=loopback` + SSH tunnel |
| OOM after OpenClaw start | gateway + content + OpenClaw | Disable local LLM/browser; fallback [OPENCLAW-LAB.md](OPENCLAW-LAB.md) §7.3 |
| Phantom process killer | Android 12+ | `adb shell settings put global max_phantom_processes 2147483647` |
| OpenClaw dies when SSH closes | Gateway started in SSH session | Use `tmux` via `start-openclaw-phone-a.sh` |
| Two bots conflict | Same token on server + phone-a | Separate bots: `ezra-lab-srv-*` vs `ezra-lab-phone-a-*` |
| `demo:preflight` fails step 3 | OpenClaw down | `bash restart-openclaw-phone-a.sh`; check `~/phone-lab/logs/openclaw-phone-a.log` |
| Watchdog restarts OpenClaw loop | Onboard incomplete | Finish `openclaw onboard`; verify `verify-openclaw-phone-a.sh` |

See [PHASE-14-DEPLOY.md](PHASE-14-DEPLOY.md), [OPENCLAW-SERVER-RUNBOOK.md](OPENCLAW-SERVER-RUNBOOK.md).

---

## Security (lab only)

- Do not expose lab ports to public internet without Tailscale or tunnel.
- Do not use production JWT secrets or DB passwords on phones.
- Invite only trusted devices to the tailnet.
