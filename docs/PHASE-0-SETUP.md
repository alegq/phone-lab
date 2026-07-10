# Phase 0 — Setup Guide (Tailscale + Termux)

Step-by-step for **Windows dev PC + 2 Android phones**. Estimated time: 2–4 hours.

**Acceptance:** from dev PC, `npm run verify:mesh` exits 0.

---

## Prerequisites

- 2 Android phones (10+, 4+ GB RAM recommended)
- USB charging or dock (keep phones powered during lab)
- Google account or email for Tailscale
- Dev PC with Node.js 18+

---

## Step 0.1 — Tailscale account

1. Open [https://tailscale.com](https://tailscale.com) and sign up (free personal plan is enough).
2. Open [Admin Console → Machines](https://login.tailscale.com/admin/machines).
3. Note your **tailnet name** (e.g. `example.ts.net`) — used for MagicDNS.

---

## Step 0.2a — Tailscale on dev PC (Windows)

1. Download [Tailscale for Windows](https://tailscale.com/download/windows).
2. Install and sign in with the **same account** as step 0.1.
3. Wait until status is **Connected**.
4. Get IPv4:

```powershell
tailscale ip -4
```

Example output: `100.64.0.5`

5. Copy `mesh.env.example` → `mesh.env` in the `phone-lab` folder:

```powershell
cd C:\workspace\Ezrababait-2023\phone-lab
copy mesh.env.example mesh.env
```

6. Set `DEV_PC_IP=100.64.0.5` (your actual IP) in `mesh.env`.

---

## Step 0.2b — Tailscale on phone A (edge / gateway)

**Phone A** = better Wi‑Fi, often on charger — browser entry point in phase 2.

1. Install **Tailscale** from Google Play (or [direct APK](https://tailscale.com/download/android)).
2. Sign in with the **same Tailscale account**.
3. Enable VPN; wait for **Connected**.
4. In [Admin Console](https://login.tailscale.com/admin/machines):
   - Find this device → **Rename** → `phone-a`
   - Copy **Tailscale IPv4** (100.x.x.x)
5. In `mesh.env` on PC:

```env
PHONE_A_IP=100.x.x.x
PHONE_A_HOSTNAME=phone-a
```

6. Update [DEVICE-REGISTRY.md](DEVICE-REGISTRY.md) row for phone-a.

---

## Step 0.2c — Tailscale on phone B (agents)

Same as 0.2b, but rename device to **`phone-b`** and set:

```env
PHONE_B_IP=100.x.x.x
PHONE_B_HOSTNAME=phone-b
```

---

## Step 0.3 — Verify Tailscale from PC (quick)

```powershell
ping -n 2 100.x.x.x   # phone-a IP
ping -n 2 100.x.x.x   # phone-b IP
```

If ping fails, try:

```powershell
tailscale ping phone-a
tailscale ping phone-b
```

---

## Step 0.4 — Termux on both phones

### Install Termux

- **Recommended:** [termux.dev](https://termux.dev/) instructions (F-Droid or GitHub releases).
- Avoid outdated Play Store builds if possible.

Install on **both** phone-a and phone-b.

### Run bootstrap script

**Option A — after git clone (phase 1+):**

```bash
cd ~/phone-lab
bash scripts/termux/bootstrap.sh
```

**Option B — manual copy (phase 0, before clone):**

1. On PC, open `scripts/termux/bootstrap.sh`.
2. On each phone in Termux, create the file:

```bash
mkdir -p ~/phone-lab/scripts/termux
nano ~/phone-lab/scripts/termux/bootstrap.sh
# paste contents, save (Ctrl+O, Enter, Ctrl+X)
chmod +x ~/phone-lab/scripts/termux/bootstrap.sh
bash ~/phone-lab/scripts/termux/bootstrap.sh
```

**Option C — adb push (if USB debugging enabled):**

```powershell
adb push scripts\termux\bootstrap.sh /sdcard/Download/bootstrap.sh
# In Termux:
cp /sdcard/Download/bootstrap.sh ~/phone-lab/scripts/termux/bootstrap.sh
bash ~/phone-lab/scripts/termux/bootstrap.sh
```

### Expected bootstrap output

- `nodejs-lts` and `git` installed
- `node --version` shows v18+ (or v20+)
- `~/phone-lab/logs` directory created

Repeat on **both** phones.

---

## Step 0.5 — Battery optimization (both phones)

Android may kill Termux/Tailscale in background. For each app on **both** phones:

1. **Settings → Apps → Termux → Battery** → **Unrestricted** (or "Don't optimize").
2. **Settings → Apps → Tailscale → Battery** → **Unrestricted**.
3. Keep phones **on charger** during lab sessions.

OEM-specific paths:

| OEM | Path hint |
|-----|-----------|
| Samsung | Battery → Background usage limits → remove Termux/Tailscale from sleeping apps |
| Xiaomi | Battery → App battery saver → No restrictions |
| Stock Android | Apps → Special access → Battery optimization → All apps → Termux, Tailscale → Don't optimize |

---

## Step 0.6 — Mesh verification from PC

1. Ensure `mesh.env` has all three IPs filled (`PHONE_A_IP`, `PHONE_B_IP`, `DEV_PC_IP`).
2. Run:

```powershell
cd C:\workspace\Ezrababait-2023\phone-lab
npm run verify:mesh
```

3. On success, update [DEVICE-REGISTRY.md](DEVICE-REGISTRY.md): set phone-a and phone-b **Status** to `online`.

---

## Phase 0 checklist

```
[ ] Tailscale account created
[ ] Tailscale on dev PC — Connected
[ ] Tailscale on phone-a — Connected, renamed
[ ] Tailscale on phone-b — Connected, renamed
[ ] mesh.env filled (3 IPs)
[ ] Termux + bootstrap on phone-a (node >= 18)
[ ] Termux + bootstrap on phone-b (node >= 18)
[ ] Battery Unrestricted for Termux + Tailscale (both phones)
[ ] npm run verify:mesh → exit 0
[ ] DEVICE-REGISTRY.md updated
```

---

## Next: Phase 7

When all boxes are checked, deploy prod stack — see [CURRENT-ARCHITECTURE.md](CURRENT-ARCHITECTURE.md) and [PHASE-7-DEPLOY.md](PHASE-7-DEPLOY.md).
