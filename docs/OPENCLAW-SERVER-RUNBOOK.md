# OpenClaw — prod server runbook

> **Контекст:** [OPENCLAW-LAB.md](OPENCLAW-LAB.md) — параллельный spike на сервере, factory остаётся `api-agents`.  
> **phone-a deploy:** [PHASE-14-DEPLOY.md](PHASE-14-DEPLOY.md)

Серверный инстанс **openclaw-server** — стабильный 24/7, sandbox мессенджеры без Android sleep.

---

## Prerequisites

| Item | Requirement |
|------|-------------|
| OS | Linux (официально поддерживаемый путь OpenClaw) |
| Node.js | 22+ (`node --version`) |
| npm | global install path writable |
| Tailscale | Опционально для mesh smoke с dev-pc |
| Secrets | LLM API key, **отдельный** Telegram bot token |

**Не использовать** тот же Telegram bot token, что на phone-a.

---

## 1. Install

```bash
npm install -g openclaw@latest
openclaw --version
```

Upstream docs: [docs.openclaw.ai](https://docs.openclaw.ai/)

---

## 2. Onboard + systemd daemon

```bash
openclaw onboard --install-daemon
```

Wizard:

| Setting | Value |
|---------|-------|
| Gateway port | `18789` |
| Bind | `127.0.0.1` или `0.0.0.0` (по политике сервера) |
| LLM provider | Cloud API (Gemini, Anthropic, OpenAI, …) |
| Telegram | Sandbox bot `ezra-lab-srv-*` (BotFather) |
| Workspace | `~/openclaw-workspace` или git clone (см. [openclaw-workspace/README.md](../openclaw-workspace/README.md)) |

`--install-daemon` создаёт **systemd user service**. Проверка:

```bash
systemctl --user status openclaw-gateway
systemctl --user enable openclaw-gateway
```

Для always-on без logout:

```bash
sudo loginctl enable-linger $USER
```

Аудит unit:

```bash
openclaw doctor
```

---

## 3. Gateway token (secrets)

Токен gateway хранить **вне git**:

- `~/.openclaw/openclaw.json` (permissions 600)
- или env `OPENCLAW_GATEWAY_TOKEN` в systemd unit

Не коммитить в `infra-config` или phone-lab.

---

## 4. Health smoke

```bash
curl -s http://127.0.0.1:18789/health
openclaw doctor
```

С dev-pc (если Tailscale на сервере):

```bash
curl -s http://<server-tailscale-ip>:18789/health
```

Dashboard (локально на сервере):

```bash
openclaw dashboard
# или http://127.0.0.1:18789/
```

---

## 5. Telegram sandbox validation

1. Создать бота `ezra-lab-srv-<name>` через [@BotFather](https://t.me/BotFather)
2. Подключить в onboard / channel config
3. Отправить тест: `ping lab server`
4. Проверить transcript в workspace logs
5. **Не** использовать token phone-a бота `ezra-lab-phone-a-*`

Checklist:

- [ ] Bot отвечает в Telegram
- [ ] Gateway health 200
- [ ] `openclaw doctor` без critical errors
- [ ] Token phone-a бота **не** настроен на этом инстансе

---

## 6. Workspace sync

```bash
cd ~/openclaw-workspace
git clone <repo-url> .   # или init from phone-lab template
git pull                 # после review изменений skills/SOUL.md
```

Секреты и channel tokens — **per-host**, не в git. См. [openclaw-workspace/README.md](../openclaw-workspace/README.md).

---

## 7. Spike → delivery

Эксперименты на сервере переносятся в `api-agents` только через human review:

```
Spike на openclaw-server
  → transcript export
  → review checklist ([OPENCLAW-SPIKE-WORKFLOW.md](OPENCLAW-SPIKE-WORKFLOW.md))
  → PR в api-agents (handler | workflow node | prompt)
  → smoke:phase7+ на phone-lab mesh
  → prod smoke на сервере (при необходимости)
```

**Запрещено:** прямая запись OpenClaw в Postgres phone-b или prod DB без workflow.

---

## 8. Operations

### Restart

```bash
systemctl --user restart openclaw-gateway
```

### Logs

```bash
journalctl --user -u openclaw-gateway -f
```

### Upgrade

```bash
npm install -g openclaw@latest
openclaw doctor
systemctl --user restart openclaw-gateway
```

### Rollback

```bash
systemctl --user stop openclaw-gateway
systemctl --user disable openclaw-gateway
# npm install -g openclaw@<previous-version>
```

---

## 9. Acceptance (server track)

- [ ] `curl http://127.0.0.1:18789/health` → 200
- [ ] systemd user service enabled + running
- [ ] Sandbox Telegram bot `ezra-lab-srv-*` отвечает
- [ ] Token отличается от phone-a
- [ ] Workspace git настроен (или template скопирован)

---

## 10. Out of scope

- Изменения в `infra/` Helm/Docker — не требуются для Phase 14
- Публичный subdomain для OpenClaw UI
- Прямая интеграция с `ezrababait.bufsa.com` без review
- OpenClaw на phone-b
