# Phase 14 — Telegram sandbox acceptance checklist

> Run after OpenClaw gateway health passes on each instance.  
> **One bot — one gateway.** Different tokens for server vs phone-a.

---

## Bot naming

| Instance | Prefix | Example |
|----------|--------|---------|
| openclaw-server | `ezra-lab-srv-` | `ezra-lab-srv-ping` |
| openclaw-phone-a | `ezra-lab-phone-a-` | `ezra-lab-phone-a-ping` |

Create via [@BotFather](https://t.me/BotFather). Store tokens in `~/.openclaw/` only — never git.

---

## Server (`openclaw-server`)

- [ ] `curl -s http://127.0.0.1:18789/health` → 200
- [ ] `systemctl --user status openclaw-gateway` → active
- [ ] Bot `ezra-lab-srv-*` connected in onboard / channel config
- [ ] Send `ping lab server` → bot replies
- [ ] Transcript visible in workspace logs
- [ ] Token **≠** phone-a bot token
- [ ] Record pass in spike note: `openclaw-workspace/spikes/YYYY-MM-DD-telegram-server.md`

Runbook: [OPENCLAW-SERVER-RUNBOOK.md](OPENCLAW-SERVER-RUNBOOK.md) §5

---

## phone-a (`openclaw-phone-a`)

- [ ] `bash ~/phone-lab/scripts/termux/phone-a/verify-openclaw-phone-a.sh` → OK
- [ ] From dev-pc: `npm run smoke:phase14` → PASS (with `mesh.openclaw.env`)
- [ ] Bot `ezra-lab-phone-a-*` connected
- [ ] Send `ping lab phone-a` → bot replies
- [ ] `npm run demo:preflight` → PASS (with `OPENCLAW_ENABLED=1`)
- [ ] Token **≠** server bot token
- [ ] Record pass in spike note: `openclaw-workspace/spikes/YYYY-MM-DD-telegram-phone-a.md`

Deploy: [PHASE-14-DEPLOY.md](PHASE-14-DEPLOY.md)

---

## Phase 14 complete (all boxes)

- [ ] Server gateway health
- [ ] phone-a gateway health (Tailscale or SSH tunnel)
- [ ] Telegram sandbox on **≥1** instance (goal: **both**)
- [ ] Ports 4000 / 4010 unaffected (`npm run smoke` PASS)
- [ ] `demo:preflight` green
- [ ] [DEVICE-REGISTRY.md](DEVICE-REGISTRY.md) updated: `OpenClaw online`

---

## Spike note template

```markdown
# Spike: Telegram sandbox validation
- **Date:** YYYY-MM-DD
- **Instance:** openclaw-server | openclaw-phone-a
- **Bot:** ezra-lab-srv-* | ezra-lab-phone-a-*

## Test
User: ping lab
Bot: (response)

## Result
PASS — Phase 14 Telegram acceptance
```
