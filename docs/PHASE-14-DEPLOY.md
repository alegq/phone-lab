# Phase 14 — OpenClaw deploy (phone-a)

> **Prerequisites:** Phases 0–13 PASS, `mesh.env`, SSH keys (`npm run remote:setup`).  
> **Architecture:** [OPENCLAW-LAB.md](OPENCLAW-LAB.md) · **Plan:** [PHASE-14-IMPLEMENTATION-PLAN.md](PHASE-14-IMPLEMENTATION-PLAN.md)

OpenClaw на **phone-a only** (не phone-b — OOM). Сервер — отдельно: [OPENCLAW-SERVER-RUNBOOK.md](OPENCLAW-SERVER-RUNBOOK.md).

---

## Quick deploy (scripts only)

С dev-pc — загрузить Termux scripts и env templates:

```powershell
cd C:\workspace\Ezrababait-2023\phone-lab
npm run deploy:phase14
```

Затем на phone-a (Termux) — установка OpenClaw upstream + onboard (см. ниже).

---

## Prerequisites

| Check | Command |
|-------|---------|
| Mesh | `npm run verify:mesh` |
| Factory regression | `npm run demo:preflight` |
| Termux bootstrap | `bash ~/phone-lab/scripts/termux/bootstrap.sh` |
| Node 22+ | `node --version` (v24.x на phone-a — OK) |
| Termux:Boot | F-Droid `com.termux.boot` |
| Battery | Termux → Unrestricted |
| Phantom killer (Android 12+) | С dev-pc: `adb shell settings put global max_phantom_processes 2147483647` |

---

## Install path decision tree

```
1. Native Termux (fast path)
   npm install -g openclaw@latest
   openclaw onboard
   bash ~/phone-lab/scripts/termux/phone-a/start-openclaw-phone-a.sh
   npm run smoke:phase14
   ├─ PASS → записать "native" в DEVICE-REGISTRY
   └─ FAIL → шаг 2

2. proot Ubuntu (primary fallback)
   bash ~/phone-lab/scripts/termux/phone-a/install-openclaw-proot.sh
   # внутри proot: openclaw onboard
   bash ~/phone-lab/scripts/termux/phone-a/start-openclaw-phone-a.sh
   npm run smoke:phase14
   ├─ PASS → записать "proot" в DEVICE-REGISTRY
   └─ FAIL → шаг 3

3. Simplified fallback (OPENCLAW-LAB §7.3)
   - cloud LLM only (no local/Ollama)
   - disable browser / heavy skills
   - one channel (Telegram sandbox)
   - heavy spikes → server OpenClaw only
```

---

## Step-by-step: native Termux

### 1. Deploy scripts from dev-pc

```powershell
npm run deploy:phase14
```

### 2. Install OpenClaw (upstream)

На phone-a в Termux:

```bash
pkg install -y tmux
npm install -g openclaw@latest
openclaw onboard
```

Onboard wizard:

- Gateway port: **18789** (default)
- **Свой** sandbox Telegram bot — **не** тот же token, что на сервере
- Cloud LLM API key (Gemini и т.д.)
- Bind: **loopback** (рекомендуется на Android); для mesh — `tailnet` + auth token

### 3. Env file (optional)

```bash
cp ~/phone-lab/config/openclaw-phone-a.env.example ~/phone-lab/openclaw-phone-a.env
# edit OPENCLAW_PORT, OPENCLAW_INSTALL_MODE=native
```

### 4. Start gateway

```bash
bash ~/phone-lab/scripts/termux/phone-a/start-openclaw-phone-a.sh
bash ~/phone-lab/scripts/termux/phone-a/verify-openclaw-phone-a.sh
```

### 5. Boot on reboot

```bash
bash ~/phone-lab/scripts/termux/phone-a/install-boot-openclaw.sh
```

### 6. Mesh smoke from dev-pc

Скопировать `mesh.openclaw.env.example` → `mesh.openclaw.env`:

```powershell
copy mesh.openclaw.env.example mesh.openclaw.env
# OPENCLAW_SSH_TUNNEL=1 если gateway bind loopback
npm run smoke:phase14
npm run demo:preflight
```

---

## Step-by-step: proot Ubuntu

```bash
bash ~/phone-lab/scripts/termux/phone-a/install-openclaw-proot.sh
```

Скрипт создаёт proot Ubuntu 22.04 и печатает инструкции. Внутри proot:

```bash
proot-distro login ubuntu
npm install -g openclaw@latest
openclaw onboard
exit
```

Установить `OPENCLAW_INSTALL_MODE=proot` в `~/phone-lab/openclaw-phone-a.env`, затем:

```bash
bash ~/phone-lab/scripts/termux/phone-a/start-openclaw-phone-a.sh
```

---

## SSH tunnel (loopback bind)

Если gateway слушает только `127.0.0.1:18789` на phone-a, smoke с dev-pc использует tunnel:

```powershell
# В mesh.openclaw.env:
# OPENCLAW_SSH_TUNNEL=1
# OPENCLAW_LOCAL_PORT=18789

npm run smoke:phase14
```

Или вручную:

```powershell
ssh -N -L 18789:127.0.0.1:18789 -p 8022 u0_a360@100.120.187.10
curl http://127.0.0.1:18789/health
```

---

## Telegram sandbox (phone-a)

1. Создать бота через [@BotFather](https://t.me/BotFather) — имя `ezra-lab-phone-a-*`
2. Token **отличается** от серверного `ezra-lab-srv-*`
3. Подключить в `openclaw onboard` или channel config
4. Отправить тестовое сообщение → проверить transcript
5. Зафиксировать в spike log (см. [OPENCLAW-SPIKE-WORKFLOW.md](OPENCLAW-SPIKE-WORKFLOW.md))

---

## Acceptance (P14)

| ID | Check |
|----|-------|
| P14-1 | `GET :18789/health` → 200 (direct Tailscale или SSH tunnel) |
| P14-2 | `GET phone-b:4010/public/api/agents/health/live` → 200 |
| P14-3 | `GET phone-a:4000/api/health/live` → 200 |
| P14-4 | OpenClaw не слушает :4000 / :4010 |
| P14-5 | `npm run demo:preflight` PASS |
| P14-6 | `DEVICE-REGISTRY.md` — OpenClaw online |

```powershell
npm run smoke:phase14
```

---

## Watchdog + session-start

После deploy Phase 14 scripts:

```powershell
npm run deploy:watchdog
npm run deploy:session-start
```

OpenClaw проверяется в `watch-stack-phone-a.sh` если `~/phone-lab/.openclaw-installed` существует.

---

## Rollback

```bash
# Stop OpenClaw
tmux kill-session -t oc 2>/dev/null || true
pkill -f "openclaw gateway" 2>/dev/null || true

# Remove boot entry
rm -f ~/.termux/boot/start-openclaw-phone-a.sh
rm -f ~/phone-lab/.openclaw-installed

# Verify factory
# dev-pc: npm run demo:preflight
```

---

## Troubleshooting

См. [TROUBLESHOOTING.md](TROUBLESHOOTING.md) — секция **Phase 14 — OpenClaw**.
