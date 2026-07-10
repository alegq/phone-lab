# Phase 11 — api-auth + admin JWT через gateway (phone-a → phone-b)

Развернуть prod **api-auth** на **phone-b**, починить **RabbitMQ cross-phone**, обновить **gateway на phone-a** и пройти `verify-gateway-agents.mjs` — admin login + `/api/agents/admin/*` **через gateway**, а не напрямую на agents.

**Предусловия:** Phase 9 PASS (`npm run smoke:gateway-prod`). Рекомендуется Phase 10 PASS (`npm run smoke:phase10`) — live Gemini для `blog_content_generation` в verify-скрипте.

---

## Зачем Phase 11

| Сейчас (Phase 9) | После Phase 11 |
|------------------|----------------|
| Gateway health OK | Gateway + **admin auth** OK |
| `/api/agents/admin/*` → 401 через gateway | Login + JWT cookie → **200** |
| Agents только напрямую `:4010` | PC/браузер ходит на **phone-a :4000** |
| `AUTH_SERVICE_URL` — заглушка | Rabbit consumers **api-auth** на phone-b |
| `FIREBASE_API_KEY` пустой на gateway | Реальный ключ для admin login |

---

## Архитектура

> **Текущий деплой (Phase 13+):** `api-content-prod` на **phone-a** :4004. См. [CURRENT-ARCHITECTURE.md](CURRENT-ARCHITECTURE.md).

```
dev-pc
  verify-gateway-agents.mjs / smoke:phase11
       ↓ Tailscale
phone-a (100.120.187.10)
  api-gateway-prod     :4000
  api-content-prod     :4004   (Phase 13 fallback)
       │ Firebase (admin login)
       │ Rabbit AMQP ──────────────┐
       │ HTTP agents proxy ────┐   │
       ↓                       ↓   ↓
phone-b (100.103.183.36)
  api-agents-prod      :4010
  api-auth-prod        :4001
  api-marketing-prod   :4008   (Phase 12)
  PostgreSQL           :5432   (DB agents + auth + marketing)
  RabbitMQ (proot)     :5672   ← expose для phone-a
```

### Цепочка admin login (как в prod)

1. `POST /api/auth/admin/login` на **gateway** (phone-a)
2. Gateway → **Firebase** `signInWithPassword` (`FIREBASE_API_KEY`)
3. Gateway → **Rabbit** `AuthGetAdminById` → consumer **api-auth** (phone-b)
4. Gateway выставляет cookie `AdminBearer` (JWT, `JWT_SECRET` общий)
5. `GET/POST /api/agents/admin/*` → `AdminJwtAuthGuard` → снова Rabbit → api-auth → proxy на agents

`AUTH_SERVICE_URL` в gateway Joi-required, но для admin flow используется **Rabbit**, не HTTP к auth.

---

## Scope Phase 11

### Включено

- `api-auth` NestJS на phone-b (`:4001`, prefix `/public/api/auth`)
- БД `auth` в существующем PostgreSQL phone-b
- Rabbit: `configure-rabbit-tailscale.sh` + проверка AMQP с phone-a
- Обновление `gateway-prod.phone-a.env`: `FIREBASE_API_KEY`, совпадение `JWT_SECRET`
- Seed тестового admin (`admin_local@dgdgd.com` / `string12` — как в `verify-gateway-agents.mjs`)
- `scripts/deploy-auth-prod.ps1`, termux boot на phone-b
- `scripts/smoke-phase11.mjs` → обёртка над `verify-gateway-agents.mjs`
- Регрессия: `smoke:gateway-prod`, `smoke:phase8` (и опционально `smoke:phase10`)

### Не включено (Phase 12+)

- Полный prod profile/content
- Profile / drivers через gateway
- MongoDB для api-auth (если понадобится отдельно)
- Публичный OAuth Google/Facebook end-to-end
- Firebase Admin SDK seed automation (только lab admin)

**Phase 12 (api-marketing):** см. [PHASE-12-DEPLOY.md](PHASE-12-DEPLOY.md).

---

## Критерии приёмки (P11)

| ID | Проверка |
|----|----------|
| P11-1 | api-auth health на phone-b (`/public/api/auth/health/live` или аналог) → 200 |
| P11-2 | Rabbit: gateway на phone-a достучался до AMQP phone-b (`rabbitmq-diagnostics` / лог без ECONNREFUSED) |
| P11-3 | `POST phone-a:4000/api/auth/admin/login` → cookie `AdminBearer` |
| P11-4 | `GET phone-a:4000/api/agents/admin/runs` с cookie → 200 |
| P11-5 | `npm run smoke:phase11` (verify-gateway-agents) PASS с dev PC |
| P11-6 | `npm run smoke:gateway-prod` + `npm run smoke:phase8` — без регрессии |

---

## План реализации (для агента / разработчика)

### 1. Конфиг phone-b — `config/auth-prod.phone-b.env.example`

```env
PORT=4001
NODE_ENV=production
FRONTEND_SERVICE_DOMAIN=5173

JWT_SECRET=9da9e6e8fdc316dc156b3dc42588006c   # = gateway
JWT_EXPIRATION=180000

DB_TYPE=postgres
DB_HOST=127.0.0.1
DB_PORT=5432
DB_USERNAME=admin
DB_PASSWORD=password123
DB_NAME=auth
DB_SYNCHRONIZE=true

RABBIT_MQ_URI=amqp://rmuser:password123@127.0.0.1:5672

FIREBASE_API_KEY=<из mesh.secrets.env / prod .env>
GOOGLE_CLIENT_ID=phone-lab-placeholder
GOOGLE_CLIENT_SECRET=phone-lab-placeholder
GOOGLE_CALLBACK=http://100.120.187.10:4000/api/auth/google/redirect
FACEBOOK_CLIENT_ID=phone-lab-placeholder
FACEBOOK_CLIENT_SECRET=phone-lab-placeholder
FACEBOOK_CALLBACK=http://100.98.162.107:3001/auth/facebook/redirect
```

### 2. PostgreSQL — вторая БД на phone-b

```bash
psql -d postgres -c "CREATE DATABASE auth OWNER admin;"
```

(идемпотентно в `setup-auth-db.sh`)

### 3. Rabbit cross-phone (обязательно для Phase 11)

```bash
bash ~/phone-lab/packages/api-agents-prod/scripts/termux/phone-b/configure-rabbit-tailscale.sh
```

С phone-a:

```bash
timeout 5 bash -c 'echo > /dev/tcp/100.103.183.36/5672' && echo OK || echo FAIL
```

### 4. Gateway env (phone-a) — дополнить

```env
FIREBASE_API_KEY=<реальный>
JWT_SECRET=9da9e6e8fdc316dc156b3dc42588006c   # тот же что api-auth
```

Перезапуск gateway после смены `.env`.

### 5. Seed admin

- Пользователь в **Firebase Auth** с email `admin_local@dgdgd.com`
- Запись в таблице `admin` (PostgreSQL `auth`) с `id` = Firebase UID и ролью `super_admin` / `users_admin`

### 6. Deploy / smoke

```powershell
.\scripts\deploy-auth-prod.ps1
# SSH → phone-b: extract, npm install --ignore-scripts, seed, boot
# обновить gateway .env на phone-a, restart gateway
npm run smoke:phase11
npm run smoke:gateway-prod
npm run smoke:phase8
```

---

## Риски

| Риск | Митигация |
|------|-----------|
| OOM на phone-b (4 GB) | charger; auth ~300–500 MB; не поднимать лишнее |
| Rabbit restart fail (уже было в Phase 9) | ручной `reset-rabbit-proot` + expose; блокер для P11-2 |
| `npm install` api-auth на Android | `PUPPETEER_SKIP_DOWNLOAD=true --ignore-scripts` |
| Firebase lab admin | один тестовый аккаунт; ключ только в `mesh.secrets.env` |
| JWT mismatch | один `JWT_SECRET` в gateway + auth `.env` |
| blog workflow в verify падает без Gemini | Phase 10 live profile или ослабить smoke (только `test_durable_workflow`) |

---

## Чеклист: что проверить руками на телефонах

Используйте после деплоя Phase 11. IP из `mesh.env`: phone-a `100.120.187.10`, phone-b `100.103.183.36`.

### A. Перед проверкой (оба телефона)

- [ ] Tailscale **Connected** на phone-a, phone-b, dev PC
- [ ] Телефоны на **зарядке**, Termux — battery **Unrestricted**
- [ ] `mesh.env` / `mesh.secrets.env` на ПК актуальны (`FIREBASE_API_KEY`, `GEMINI_API_KEY` для phase 10)
- [ ] С ПК: `npm run verify:mesh` — PASS

---

### B. phone-b-agents (Redmi Note 8T) — Termux

#### B1. Инфраструктура

```bash
# PostgreSQL
pg_ctl -D ~/phone-lab/data/postgres status
psql -d postgres -c "\l" | grep -E 'agents|auth'

# Rabbit (proot)
bash ~/phone-lab/packages/api-agents-prod/scripts/termux/phone-b/verify-rabbit-proot.sh

# Порты локально
curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:4010/public/api/agents/health/live
curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:4004/public/api/content/health/live
curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:4001/public/api/auth/health/live   # после Phase 11
```

- [ ] PostgreSQL **running**
- [ ] БД `agents` и `auth` **существуют**
- [ ] Rabbit **ping OK**
- [ ] agents `:4010` → **200**
- [ ] **api-content-prod** на phone-a `:4004` → **200** (или content на phone-b — см. [CURRENT-ARCHITECTURE.md](CURRENT-ARCHITECTURE.md))
- [ ] api-auth `:4001` → **200** (Phase 11)

#### B2. Процессы и логи

```bash
pgrep -af 'dist/main.js|api-content|postgres|rabbit'
tail -30 ~/phone-lab/logs/agents-prod.log
tail -30 ~/phone-lab/logs/content-prod.log   # Phase 13 (phone-a)
tail -30 ~/phone-lab/logs/auth-prod.log          # Phase 11
tail -30 ~/phone-lab/logs/rabbitmq-proot.log
```

- [ ] `api-agents-prod` — один процесс `dist/main.js` (agents)
- [ ] `api-auth-prod` — один процесс `dist/main.js` (auth) — **другой каталог**
- [ ] `api-content-prod` на phone-a `:4004` — running (или content на phone-b)
- [ ] В логах auth **нет** постоянных `ECONNREFUSED` к PG/Rabbit
- [ ] В логах agents **нет** `content bridge unavailable`

#### B3. Rabbit снаружи (для gateway на phone-a)

На **phone-b** (после `configure-rabbit-tailscale`):

```bash
ss -tln | grep 5672 || netstat -tln 2>/dev/null | grep 5672
```

На **phone-a** (см. раздел C3) — AMQP до `100.103.183.36:5672`.

- [ ] Порт **5672** слушает (proot forward / tailscale path)
- [ ] С phone-a TCP до `100.103.183.36:5672` — **OK**

#### B4. Env phone-b

```bash
grep -E 'JWT_SECRET|FIREBASE|RABBIT|DB_NAME|LLM_STUB|GEMINI' \
  ~/phone-lab/packages/api-agents-prod/.env
grep -E 'JWT_SECRET|FIREBASE|RABBIT|DB_NAME' \
  ~/phone-lab/packages/api-auth-prod/.env
grep INTERNAL_SERVICE_TOKEN \
  ~/phone-lab/packages/api-content-prod/.env \
  ~/phone-lab/packages/api-agents-prod/.env
```

- [ ] `JWT_SECRET` **одинаковый** в auth и (после обновления) в gateway на phone-a
- [ ] `INTERNAL_SERVICE_TOKEN` совпадает у agents и api-content-prod
- [ ] `RABBIT_MQ_URI` → `127.0.0.1:5672` на phone-b сервисах

---

### C. phone-a-gateway (Xiaomi 14T) — Termux

#### C1. Gateway prod

```bash
pgrep -af 'api-gateway-prod|dist/main.js'
curl -s http://127.0.0.1:4000/api/health/live
curl -s http://127.0.0.1:4000/api/health/ready
tail -40 ~/phone-lab/logs/gateway-prod.log
```

- [ ] Только `api-gateway-prod` на :4000
- [ ] Есть **один** `api-gateway-prod` (`~/phone-lab/packages/api-gateway-prod/dist/main.js`)
- [ ] `/api/health/live` → `{"status":"alive"}`
- [ ] `/api/health/ready` → `status: ok`
- [ ] Лог: `Nest application successfully started`, **нет** `EADDRINUSE :4000`
- [ ] Лог: **нет** повторяющихся `OAuth2Strategy requires a clientID`

#### C2. Env gateway (критично для Phase 11)

```bash
grep -E 'FIREBASE_API_KEY|JWT_SECRET|RABBIT|AGENTS_INTERNAL|ALLOWED_ORIGIN' \
  ~/phone-lab/packages/api-gateway-prod/.env
```

- [ ] `FIREBASE_API_KEY` — **не пустой** (реальный ключ)
- [ ] `JWT_SECRET` = как на api-auth phone-b
- [ ] `AGENTS_INTERNAL_URL=http://100.103.183.36:4010`
- [ ] `RABBIT_MQ_URI_EZRABA` → `100.103.183.36:5672`
- [ ] `ALLOWED_ORIGIN_ADMIN_DEV` = Tailscale IP dev PC + порт фронта (например `http://100.98.162.107:5173`)

#### C3. Сеть phone-a → phone-b

```bash
curl -s -o /dev/null -w "%{http_code}" http://100.103.183.36:4010/public/api/agents/health/live
timeout 5 bash -c 'echo > /dev/tcp/100.103.183.36/5672' && echo AMQP_OK || echo AMQP_FAIL
```

- [ ] HTTP до agents phone-b → **200**
- [ ] TCP AMQP 5672 → **OK** (иначе admin JWT через gateway не заработает)

#### C4. Admin login локально на phone-a (ручной smoke)

```bash
curl -s -X POST http://127.0.0.1:4000/api/auth/admin/login \
  -H 'Content-Type: application/json' \
  -H 'Origin: http://100.98.162.107:5173' \
  -d '{"identifier":"admin_local@dgdgd.com","password":"string12"}' \
  -D - -o /dev/null | grep -i set-cookie
```

- [ ] HTTP **200** (не 401)
- [ ] В ответе есть `Set-Cookie` с **AdminBearer**

(Полный прокси agents — со cookie в следующем запросе к `/api/agents/admin/runs`.)

---

### D. dev PC (Windows)

#### D1. Автоматические smoke

```powershell
cd C:\workspace\Ezrababait-2023\phone-lab
npm run smoke:gateway-prod
npm run smoke:phase8
npm run smoke:phase11      # verify-gateway-agents через phone-a
# опционально:
npm run smoke:phase10
```

- [ ] `smoke:gateway-prod` — PASS
- [ ] `smoke:phase8` — PASS (прямой agents — регрессия)
- [ ] `smoke:phase11` — PASS (login + runs + workflow через gateway)
- [ ] `smoke:phase10` — PASS (если включён live Gemini)

#### D2. Ручной verify (как в prod)

```powershell
$env:GATEWAY_URL="http://100.120.187.10:4000"
$env:ADMIN_ORIGIN="http://100.98.162.107:5173"
node ..\api-agents\scripts\verify-gateway-agents.mjs
```

- [ ] `OK admin login`
- [ ] `OK gateway → agents admin/runs`
- [ ] `OK gateway started run …`
- [ ] `OK gateway blog_content_generation → waiting_approval|completed`

#### D3. Негативные проверки

```powershell
# Без cookie — должен быть 401
curl.exe -s -o NUL -w "%{http_code}" http://100.120.187.10:4000/api/agents/admin/runs
```

- [ ] Без JWT → **401** (guard работает)
- [ ] Прямой agents по-прежнему доступен: `http://100.103.183.36:4010/...` (для отладки)

---

### E. После перезагрузки телефона (MIUI)

- [ ] phone-b: `boot-stack-phone-b.sh` поднял PG + Rabbit + content + agents + **auth**
- [ ] phone-a: `boot-gateway-phone-a.sh` поднял prod gateway
- [ ] Через 2–3 мин с ПК: `npm run smoke:phase11` — PASS

---

## Следующая фаза

- **Phase 12 — api-marketing:** [PHASE-12-DEPLOY.md](PHASE-12-DEPLOY.md)
- Admin UI / фронт с Tailscale origin на gateway
- Profile service или заглушки для остальных gateway routes
- Полный `api-content-prod` (Phase 13)
- Ужесточение CORS / prod `NODE_ENV`
