# Ezrababait OpenClaw Workspace

> Shared skills, SOUL.md, and spike notes for **openclaw-server** and **openclaw-phone-a**.  
> **Repo name (TBD):** `ezrababait-openclaw-workspace` — init as standalone git repo or copy this template.

---

## Purpose

- Version-controlled agent personality (`SOUL.md`) and skills
- Spike transcripts before promotion to `api-agents`
- **Not** for secrets or channel tokens

---

## Layout

```
openclaw-workspace/
├── README.md
├── SOUL.md                 # Agent personality / system context
├── skills/                 # Custom skills (upstream format)
│   └── .gitkeep
├── spikes/                 # Spike notes (see OPENCLAW-SPIKE-WORKFLOW.md)
│   └── .gitkeep
└── hosts/                  # Per-host notes (not secrets)
    ├── server.md
    └── phone-a.md
```

---

## Sync workflow

1. Edit skills / SOUL.md locally or on server
2. `git commit` + `git push`
3. On each instance:

```bash
cd ~/openclaw-workspace
git pull
# restart gateway if needed:
systemctl --user restart openclaw-gateway   # server
# or: bash ~/phone-lab/scripts/termux/phone-a/restart-openclaw-phone-a.sh
```

---

## Per-host config (NOT in git)

| Secret / config | Server | phone-a |
|-----------------|--------|---------|
| Telegram bot token | `ezra-lab-srv-*` | `ezra-lab-phone-a-*` |
| LLM API keys | `~/.openclaw/` | `~/.openclaw/` or proot home |
| Gateway token | systemd env | `openclaw-phone-a.env` |

Document host-specific paths in `hosts/server.md` and `hosts/phone-a.md`.

---

## Bootstrap new repo

```bash
cd openclaw-workspace
git init
git add SOUL.md skills/ spikes/ hosts/ README.md
git commit -m "chore: initial OpenClaw workspace"
git remote add origin git@github.com:Ezrababait-2023/ezrababait-openclaw-workspace.git
git push -u origin main
```

On server:

```bash
git clone git@github.com:Ezrababait-2023/ezrababait-openclaw-workspace.git ~/openclaw-workspace
openclaw onboard  # point workspace to ~/openclaw-workspace
```

On phone-a:

```bash
git clone <repo-url> ~/openclaw-workspace
# after openclaw install — same workspace path in onboard
```

---

## Related docs

- [OPENCLAW-LAB.md](../docs/OPENCLAW-LAB.md)
- [OPENCLAW-SPIKE-WORKFLOW.md](../docs/OPENCLAW-SPIKE-WORKFLOW.md)
- [PHASE-14-DEPLOY.md](../docs/PHASE-14-DEPLOY.md)
