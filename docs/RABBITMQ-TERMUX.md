# RabbitMQ on phone-b — proot Debian (primary)

## Summary

**RabbitMQ runs inside proot Debian** on phone-b, not as a Termux package.

- AMQP: `amqp://rmuser:password123@127.0.0.1:5672` (unchanged for api-agents)
- Version: RabbitMQ **3.x** from Debian (stable on ARM/Android)
- Termux `rabbitmq-server` 4.3 + Erlang 29 is **broken** — do not use

`health/ready` on api-agents does **not** check RabbitMQ. Use `verify-rabbit-proot.sh` after setup or boot.

## Architecture

```
Termux (phone-b)
  ├── PostgreSQL :5432
  ├── api-agents-prod :4010
  └── proot-distro login debian
        └── rabbitmq-server :5672 (127.0.0.1 only)
```

## One-time setup

From phone-b Termux (or from PC: `npm run setup:phone-b-rabbit`):

```bash
cd ~/phone-lab/packages/api-agents-prod
bash scripts/termux/phone-b/setup-proot-debian.sh   # 20–40 min first time
bash scripts/termux/phone-b/setup-rabbit-proot.sh
bash scripts/termux/phone-b/verify-rabbit-proot.sh
```

Optional — free RAM if old Termux packages were installed:

```bash
pkg uninstall rabbitmq-server erlang
```

Full data-plane (PostgreSQL + proot Rabbit):

```bash
bash scripts/termux/phone-b/setup-data-plane.sh
```

## Boot / daily use

`boot-stack-phone-b.sh` calls `start-rabbit-proot.sh` before agents.

```bash
bash scripts/termux/phone-b/start-rabbit-proot.sh
bash scripts/termux/phone-b/verify-rabbit-proot.sh
```

## Scripts

| Script | Purpose |
|--------|---------|
| `proot-env.sh` | Shared `PROOT_DISTRO`, credentials, `proot_run()` |
| `setup-proot-debian.sh` | Install proot-distro + Debian rootfs |
| `setup-rabbit-proot.sh` | apt install rabbitmq-server in proot, create user |
| `start-rabbit-proot.sh` | Boot: start Rabbit in proot, wait for ping |
| `verify-rabbit-proot.sh` | Port 5672 + `rabbitmq-diagnostics ping` |
| `rabbitmq-proot-ctl.sh` | `rabbitmqctl` inside proot |
| `reset-rabbit-proot.sh` | Wipe proot mnesia + re-run setup (lab) |
| `start-rabbitmq.sh` | **Deprecated** — redirects to `start-rabbit-proot.sh` |

## PC orchestration

```powershell
npm run setup:phone-b-rabbit
# or stepwise:
python scripts/remote/deploy_phone_b_stack.py --action upload
python scripts/remote/deploy_phone_b_stack.py --action proot --timeout 3600
python scripts/remote/deploy_phone_b_stack.py --action rabbit
python scripts/remote/deploy_phone_b_stack.py --action verify
```

## Why Termux pkg failed

RabbitMQ 4.3.2 + Erlang 29.0.2 on Termux/Android crashes at boot:

```
BOOT FAILED … incompatible_feature_flags … horus … extraction_denied … unknown_instruction
```

Wipe mnesia and `RABBITMQ_FEATURE_FLAGS=-khepri_db` do not fix it.

## Optional fallback — RabbitMQ on dev PC

If proot is unavailable, run Rabbit in Docker on the dev PC and point `RABBIT_MQ_URI` at `DEV_PC_IP` from `mesh.env`. See [PHONE-B-SETUP.md](PHONE-B-SETUP.md) troubleshooting.

## See also

- [PHONE-B-SETUP.md](PHONE-B-SETUP.md) — full phone-b playbook
- [PHASE-7-DEPLOY.md](PHASE-7-DEPLOY.md)
- [REMOTE-ACCESS.md](REMOTE-ACCESS.md)
