/**
 * Smoke test for the public Cloudflare domain (no Tailscale required).
 *
 * Usage:
 *   ADMIN_PHONE_URL="https://admin-phone.bufsa.com" node scripts/smoke-public-domain.mjs
 */

import process from 'node:process';

const base = (process.env.ADMIN_PHONE_URL || 'https://admin-phone.bufsa.com').replace(/\/$/, '');

async function getJson(path) {
  const url = `${base}${path}`;
  const res = await fetch(url, { headers: { accept: 'application/json' } });
  const text = await res.text();
  let data;
  try {
    data = text ? JSON.parse(text) : null;
  } catch {
    data = text;
  }
  return { url, status: res.status, ok: res.ok, data };
}

function assert(condition, message) {
  if (!condition) {
    console.error(`FAIL: ${message}`);
    process.exitCode = 1;
  }
}

console.log(`Public base: ${base}`);

const live = await getJson('/api/health/live');
console.log('GET /api/health/live', live.status, live.data);
assert(live.ok, `/api/health/live not OK (${live.status})`);
assert(live.data?.status === 'alive', `unexpected live payload: ${JSON.stringify(live.data)}`);

const ready = await getJson('/api/health/ready');
console.log('GET /api/health/ready', ready.status, ready.data);
assert(ready.ok, `/api/health/ready not OK (${ready.status})`);

if (!process.exitCode) {
  console.log('OK: public domain smoke passed');
}

