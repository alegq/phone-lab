# RAM expansion baseline — BEFORE

Captured: 2026-07-09 ~15:48 UTC+3 (dev PC)

Compare with `ram-expansion-after.md` after enabling MIUI **Расширение памяти** + reboot.

---

## phone-a (Xiaomi 14T, 100.120.187.10)

| Metric | Value |
|--------|-------|
| Uptime | 20 days, 20:55 |
| CPU cores | 8 |
| Load average | 16.06, 15.71, 16.30 |
| RAM total | 11 Gi (~11.0 GB) |
| RAM used | 6.9 Gi |
| RAM free | 266 Mi |
| RAM available | 4.1 Gi |
| Swap total | 11 Gi (~12.0 GB) |
| Swap used | 7.2 Gi |
| Swap free | 4.8 Gi |
| MemTotal (kB) | 11585708 |
| MemAvailable (kB) | 4267144 |
| SwapTotal (kB) | 12582908 |
| SwapFree (kB) | 5006816 |

**Top processes (RSS):** postgres-marketing ~19 MB, cloudflared ~9 MB, node (gateway?) ~8 MB, api-content-prod ~8 MB

**Services:** gateway :4000 → `{"status":"alive"}`

---

## phone-b (Redmi Note 8T, 100.103.183.36)

| Metric | Value |
|--------|-------|
| Uptime | 2 days, 5:21 |
| CPU cores | 6 |
| Load average | 1.03, 2.24, 2.39 |
| RAM total | 3.5 Gi (~3.6 GB) |
| RAM used | 2.1 Gi |
| RAM free | 113 Mi |
| RAM available | 1.2 Gi |
| Swap total | 2.2 Gi (~2.2 GB) |
| Swap used | 1.2 Gi |
| Swap free | 990 Mi |
| MemTotal (kB) | 3720352 |
| MemAvailable (kB) | 1304968 |
| SwapTotal (kB) | 2306044 |
| SwapFree (kB) | 1014620 |

**Top processes (RSS):** RabbitMQ beam ~22 MB, api-auth ~22 MB, api-marketing ~14 MB, api-agents ~8 MB

**Services:** agents :4010 → `{"status":"alive"}`

---

## What to watch AFTER reboot + RAM expansion

1. **SwapTotal** — should increase if MIUI adds virtual RAM (e.g. phone-b: 2.2 Gi → 6+ Gi)
2. **MemAvailable** — ideally higher under same load
3. **Swap used / SwapTotal ratio** — lower is better
4. Re-run boot stack / open Termux; verify health endpoints
