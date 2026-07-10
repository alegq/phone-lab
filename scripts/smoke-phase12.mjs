#!/usr/bin/env node
/**
 * Phase 12 smoke — api-marketing health + gateway facebook/portfolios proxy.
 *
 * Usage:
 *   npm run smoke:phase12
 *
 * Optional env:
 *   MARKETING_URL, GATEWAY_URL, ADMIN_EMAIL, ADMIN_PASSWORD, ADMIN_ORIGIN
 *   PUBLIC_ADMIN_URL (default https://admin-phone.bufsa.com)
 *   SKIP_PUBLIC=1
 */

import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { existsSync, readFileSync } from 'node:fs';
import { loadMeshEnv, resolveGatewayUrl } from './lib/mesh-env.mjs';

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = join(__dirname, '..');

function loadMarketingUrl() {
  const fromEnv = process.env.MARKETING_URL?.replace(/\/$/, '');
  if (fromEnv) return fromEnv;

  const meshMarketing = join(ROOT, 'mesh.marketing.env');
  if (existsSync(meshMarketing)) {
    const content = readFileSync(meshMarketing, 'utf8');
    for (const line of content.split('\n')) {
      const trimmed = line.trim();
      if (trimmed.startsWith('MARKETING_IP=')) {
        const ip = trimmed.slice('MARKETING_IP='.length).trim();
        if (ip) return `http://${ip}:4008`;
      }
    }
  }

  const mesh = loadMeshEnv(ROOT);
  const ip = mesh.PHONE_B_IP || '100.103.183.36';
  return `http://${ip}:4008`;
}

const MARKETING_URL = loadMarketingUrl();
const GATEWAY_URL = resolveGatewayUrl(ROOT, process.env.GATEWAY_URL);
const ADMIN_EMAIL = process.env.ADMIN_EMAIL ?? 'admin_local@dgdgd.com';
const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD ?? 'string12';
const ADMIN_ORIGIN = process.env.ADMIN_ORIGIN ?? 'https://admin-phone.bufsa.com';
const PUBLIC_ADMIN_URL = (process.env.PUBLIC_ADMIN_URL ?? 'https://admin-phone.bufsa.com').replace(/\/$/, '');
const SKIP_PUBLIC = process.env.SKIP_PUBLIC === '1';

async function request(url, options = {}) {
  const res = await fetch(url, { signal: AbortSignal.timeout(30000), ...options });
  const text = await res.text();
  let data;
  try {
    data = text ? JSON.parse(text) : null;
  } catch {
    data = text;
  }
  return { status: res.status, data, url, headers: res.headers };
}

function assertOk(label, result, expectedStatus = 200, check) {
  if (result.status !== expectedStatus) {
    throw new Error(`${label}: HTTP ${result.status} at ${result.url} — ${JSON.stringify(result.data).slice(0, 300)}`);
  }
  if (check && !check(result.data)) {
    throw new Error(`${label}: unexpected body ${JSON.stringify(result.data).slice(0, 300)}`);
  }
  console.log(`OK  ${label}`);
}

function parseSetCookie(setCookie) {
  if (!setCookie) return '';
  const parts = Array.isArray(setCookie) ? setCookie : [setCookie];
  return parts.map((c) => c.split(';')[0]).join('; ');
}

async function adminLogin(gatewayUrl) {
  const res = await fetch(`${gatewayUrl}/api/auth/admin/login`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Origin: ADMIN_ORIGIN,
    },
    body: JSON.stringify({
      identifier: ADMIN_EMAIL,
      password: ADMIN_PASSWORD,
    }),
    signal: AbortSignal.timeout(30000),
  });
  const text = await res.text();
  let data;
  try {
    data = text ? JSON.parse(text) : null;
  } catch {
    data = text;
  }
  if (res.status !== 201 && res.status !== 200) {
    throw new Error(`admin login failed: HTTP ${res.status} — ${JSON.stringify(data).slice(0, 200)}`);
  }
  const cookie = parseSetCookie(res.headers.getSetCookie?.() ?? res.headers.get('set-cookie'));
  if (!cookie.includes('AdminBearer')) {
    throw new Error('admin login: missing AdminBearer cookie');
  }
  return cookie;
}

async function main() {
  console.log('Phone Lab — smoke phase 12 (api-marketing + gateway proxy)\n');
  console.log(`  MARKETING_URL=${MARKETING_URL}`);
  console.log(`  GATEWAY_URL=${GATEWAY_URL}`);
  console.log(`  ADMIN_ORIGIN=${ADMIN_ORIGIN}\n`);

  const live = await request(`${MARKETING_URL}/api/health/live`);
  assertOk('marketing health/live', live, 200, (d) => d?.status === 'alive');

  const ready = await request(`${MARKETING_URL}/api/health/ready`);
  assertOk('marketing health/ready', ready, 200, (d) => d?.status === 'ok');

  const cookie = await adminLogin(GATEWAY_URL);
  console.log('OK  admin login (AdminBearer cookie)');

  const portfolios = await request(`${GATEWAY_URL}/api/facebook/portfolios`, {
    headers: {
      Cookie: cookie,
      Origin: ADMIN_ORIGIN,
    },
  });
  if (portfolios.status === 503) {
    throw new Error(
      'gateway /api/facebook/portfolios → 503 Marketing unavailable — check MARKETING_INTERNAL_URL and marketing process',
    );
  }
  if (portfolios.status === 401) {
    throw new Error('gateway /api/facebook/portfolios → 401 — admin JWT / domain policy');
  }
  assertOk('gateway /api/facebook/portfolios (not 503)', portfolios, portfolios.status, () => true);

  if (!SKIP_PUBLIC) {
    try {
      const publicLive = await request(`${PUBLIC_ADMIN_URL}/api/health/live`);
      assertOk('public /api/health/live', publicLive, 200, (d) => d?.status === 'alive');
    } catch (e) {
      console.log(`WARN  public health skipped: ${e.message}`);
    }
  }

  console.log('\nPASS  Phone Lab phase 12 smoke (P12-1..P12-5)');
}

main().catch((e) => {
  console.error(`\nFAIL  ${e.message}`);
  process.exit(1);
});
