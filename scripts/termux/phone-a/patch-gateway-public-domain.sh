#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ENV="$HOME/phone-lab/packages/api-gateway-prod/.env"

if [ ! -f "$ENV" ]; then
  echo "Missing $ENV"
  exit 1
fi

if ! grep -q '^ADMIN_USERS_DOMAINS=' "$ENV"; then
  echo 'ADMIN_USERS_DOMAINS=admin-users.bufsa.com,admin.ezrababait.co.il,admin-phone.bufsa.com' >> "$ENV"
else
  sed -i 's|^ADMIN_USERS_DOMAINS=.*|ADMIN_USERS_DOMAINS=admin-users.bufsa.com,admin.ezrababait.co.il,admin-phone.bufsa.com|' "$ENV"
fi

sed -i 's|^ALLOWED_ORIGIN_ADMIN_DEV=.*|ALLOWED_ORIGIN_ADMIN_DEV=https://admin-phone.bufsa.com|' "$ENV"

grep -E 'ADMIN_USERS_DOMAINS|ALLOWED_ORIGIN_ADMIN_DEV' "$ENV"
