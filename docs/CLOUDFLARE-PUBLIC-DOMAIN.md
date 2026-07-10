# Cloudflare public domain → phone servers (admin-phone.bufsa.com)

This guide exposes phone services over normal HTTPS **without** exposing phone IPs/ports publicly.

## Target

- UI: Cloudflare Pages at `https://admin-phone.bufsa.com`
- API (same-origin): `https://admin-phone.bufsa.com/api/*`
- Private connector: Cloudflare Tunnel (`cloudflared`) running on **phone-a** → `http://127.0.0.1:4000` (gateway)

## High-level flow

1. Browser calls `https://admin-phone.bufsa.com/api/...` (same origin).
2. Cloudflare Worker route proxies `/api/*` to `https://api.admin-phone.bufsa.com/*`.
3. `api.admin-phone.bufsa.com` is a Cloudflare Tunnel hostname that reaches phone-a locally.
4. phone-a gateway calls phone-b services over the private network (Tailscale / LAN / whatever your phone mesh uses).

## Prerequisites

- Phase 9 gateway is running on **phone-a** at `http://127.0.0.1:4000` and answers:
  - `GET /api/health/live`
  - `GET /api/health/ready`
- You can run shell commands in Termux on phone-a.

## Step 1 — Cloudflare DNS hostnames

In Cloudflare DNS for `bufsa.com`:

- `admin-phone` should stay on **Cloudflare Pages** (already done).
- Create `api.admin-phone` as:
  - **Type**: CNAME
  - **Target**: any placeholder (Cloudflare Tunnel will control routing)
  - **Proxy**: ON

## Step 2 — Worker route for same-origin `/api/*`

Deploy the Worker in `cloudflare/workers/admin-phone-api-proxy/` and add a route:

- Route: `admin-phone.bufsa.com/api/*`
- Worker: `admin-phone-api-proxy`

This keeps browser calls same-origin and avoids most CORS/cookie issues.

## Step 3 — Tunnel on phone-a (cloudflared)

On phone-a:

1. Install `cloudflared`:

```bash
cd ~/phone-lab
bash scripts/termux/phone-a/install-cloudflared.sh
```

2. Login (opens a browser approval URL):

```bash
cloudflared tunnel login
```

3. Create the tunnel:

```bash
cloudflared tunnel create phone-a-gateway
```

This creates a credentials JSON under `~/.cloudflared/` (path shown in command output).

4. Create config:

```bash
mkdir -p ~/phone-lab/cloudflared
cp ~/phone-lab/scripts/cloudflared/phone-a/config.yml.example ~/phone-lab/cloudflared/config.yml
```

Edit `~/phone-lab/cloudflared/config.yml` and set `credentials-file` to the JSON you got in step 3.

5. Route hostname to tunnel (Cloudflare-side DNS binding):

```bash
cloudflared tunnel route dns phone-a-gateway api.admin-phone.bufsa.com
```

6. Run the tunnel:

```bash
bash ~/phone-lab/scripts/termux/phone-a/start-cloudflared-tunnel.sh
tail -50 ~/phone-lab/logs/cloudflared-phone-a.log
```

7. Optional auto-start on reboot:

```bash
bash ~/phone-lab/scripts/termux/phone-a/install-boot-cloudflared.sh
```

The ingress rule maps:

- `api.admin-phone.bufsa.com` → `http://127.0.0.1:4000`

## Step 4 — Public verification

From any machine (no Tailscale needed):

- `GET https://admin-phone.bufsa.com/api/health/live` should return `{ "status": "alive" }`.

Or from the repo root:

```powershell
npm run smoke:public
```

## Notes

- If you later enable Phase 11 (admin login cookies + Rabbit), `/api/*` still goes through the same path; only the gateway internals change.
- Keep phones private: do **not** port-forward router ports to phones.

## CORS / cookies

- With the **Worker same-origin** approach (`admin-phone.bufsa.com/api/*`), the browser sees a single origin and CORS is usually not a blocker.
- If you later switch to a separate API domain (not recommended), you must allow the UI origin and enable credentials if using cookies.

## If you see Cloudflare 522

522 means Cloudflare can’t reach the “origin” for `/api/*`. In this setup, that almost always means:

- Worker route is in place, but `api.admin-phone.bufsa.com` is not routed to the tunnel yet, or
- `cloudflared` is not running / can’t connect, or
- gateway on phone-a is not listening on `127.0.0.1:4000`.

Quick checks on phone-a:

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:4000/api/health/live
pgrep -af 'cloudflared tunnel run' || true
tail -50 ~/phone-lab/logs/cloudflared-phone-a.log
```

