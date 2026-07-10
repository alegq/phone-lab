# Pull-deploy — api-agents (parallel to manual deploy)

Optional second channel: GitHub Actions builds `agents-prod.tgz` and publishes a Release; **phone-b** pulls it every 5 minutes via cron.

The **manual** path (`deploy-agents-prod.ps1` + Telegram/SSH) is unchanged and works in parallel.

---

## Two channels

| Channel | Trigger | Build | Delivery | Restart |
|---------|---------|-------|----------|---------|
| **Manual** (existing) | Dev PC | `.\scripts\deploy-agents-prod.ps1` | Telegram / `ssh_upload` + `tar -xzf` | `restart-agents-prod.sh` |
| **Pull** (opt-in) | `push` → `api-agents/main` | GitHub Actions → Release | phone-b cron downloads asset | `restart-agents-prod.sh` |

Both produce the same archive layout (`dist/`, `package.json`, termux scripts, `.phone-lab-release`).

Pull-deploy is **disabled by default** until you enable it on phone-b.

---

## Prerequisites

1. **First manual deploy** on phone-b — package dir must exist:
   `~/phone-lab/packages/api-agents-prod` with `.env`, PostgreSQL, RabbitMQ (see [PHASE-7-DEPLOY.md](PHASE-7-DEPLOY.md)).
2. **phone-lab on GitHub** — `Ezrababait-2023/phone-lab` (CI checks it out for termux scripts + env templates).
3. **Secrets in api-agents** (GitHub → Settings → Secrets):
   - `PHONE_LAB_REPO_TOKEN` — fine-grained PAT with **read** access to `phone-lab` (required if private).
4. **Token on phone-b** — read-only PAT in `~/phone-lab/mesh.secrets.env`:
   ```bash
   GITHUB_TOKEN=ghp_...   # scope: Contents read (public repos) or repo read (private)
   ```

---

## One-time setup

### 1. api-agents — enable CI release

Workflow: `api-agents/.github/workflows/ci_phone_lab_agents_release.yml`

- Runs on `push` to `main` (paths: `src/**`, `package.json`, `package-lock.json`) and `workflow_dispatch`.
- Does **not** change existing Docker CI (`ci_prod.yml`).
- Creates Release tag `phone-lab-agents-prod/{short_sha}` with asset `agents-prod.tgz`.

After first push to `main`, verify in GitHub → Releases.

### 2. phone-b — install pull scripts

From dev PC (SSH keys: `npm run remote:setup`):

```powershell
cd C:\workspace\Ezrababait-2023\phone-lab
npm run deploy:pull-deploy
```

On phone-b:

```bash
# Add token (once)
echo 'GITHUB_TOKEN=ghp_...' >> ~/phone-lab/mesh.secrets.env

# Enable pull-deploy
sed -i 's/PULL_DEPLOY_AGENTS_ENABLED=0/PULL_DEPLOY_AGENTS_ENABLED=1/' ~/phone-lab/pull-deploy.env

# Test without applying
bash ~/phone-lab/scripts/termux/phone-b/pull-deploy-agents.sh --dry-run
```

Cron runs every 5 minutes: `pull-deploy-agents.sh` (with `flock`).

---

## Day-to-day flow

1. Merge/push to `api-agents/main`.
2. GitHub Actions builds and publishes Release (~3–5 min).
3. Within ~5 min phone-b cron pulls `agents-prod.tgz`, extracts, runs `npm install` only if `package-lock.json` changed, restarts agents.
4. Verify from PC: `npm run smoke:phase7`.

Logs on phone-b: `tail -f ~/phone-lab/logs/pull-deploy.log`

---

## After manual deploy

Manual deploy does not update pull-deploy state. To prevent cron from re-applying an older GitHub Release:

```bash
bash ~/phone-lab/packages/api-agents-prod/scripts/termux/phone-b/pull-deploy-agents.sh --sync-state
```

This reads `.phone-lab-release` from the extracted package and marks it as current.

---

## Disable pull-deploy

```bash
# Option A — config flag
sed -i 's/PULL_DEPLOY_AGENTS_ENABLED=1/PULL_DEPLOY_AGENTS_ENABLED=0/' ~/phone-lab/pull-deploy.env

# Option B — remove cron line
crontab -l | grep -v pull-deploy-agents.sh | crontab -
```

Manual deploy continues to work unchanged.

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `GITHUB_TOKEN missing` | Add token to `~/phone-lab/mesh.secrets.env` |
| `401` / `403` from GitHub API | PAT needs read access to `api-agents` releases |
| `no release found` | Push to `main` or run workflow manually; check tag prefix `phone-lab-agents-prod/` |
| `package dir missing` | Run first manual deploy ([PHASE-7-DEPLOY.md](PHASE-7-DEPLOY.md)) |
| CI cannot checkout phone-lab | Set `PHONE_LAB_REPO_TOKEN` secret in api-agents |
| Cron re-applies old release after manual deploy | Run `pull-deploy-agents.sh --sync-state` |
| `npm install` slow | Normal on phone-b (10–20 min); only runs when lockfile changes |

---

## Files

| Location | Purpose |
|----------|---------|
| `api-agents/.github/workflows/ci_phone_lab_agents_release.yml` | Build + Release |
| `phone-lab/scripts/termux/lib/pull-deploy-lib.sh` | Shared pull logic |
| `phone-lab/scripts/termux/phone-b/pull-deploy-agents.sh` | api-agents wrapper |
| `phone-lab/scripts/termux/phone-b/install-pull-deploy-cron.sh` | Cron installer |
| `phone-lab/scripts/deploy-pull-deploy.ps1` | Upload scripts to phone-b |
| `phone-lab/config/pull-deploy.env.example` | Phone config template |

---

## Future

Same pattern can extend to `api-gateway`, `api-auth`, etc. — add a workflow per repo + a wrapper script on the target phone.
