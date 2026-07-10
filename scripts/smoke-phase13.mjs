#!/usr/bin/env node
/**
 * Phase 13 smoke — full api-content-prod on phone-b.
 *
 * Usage:
 *   npm run smoke:phase13
 *   CONTENT_URL=... INTERNAL_SERVICE_TOKEN=... npm run smoke:phase13
 */

import { spawn } from 'node:child_process';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  resolveContentUrl,
  resolveAgentsUrl,
  resolveGatewayUrl,
  resolveInternalToken,
} from './lib/mesh-env.mjs';

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = join(__dirname, '..');

const CONTENT_URL = resolveContentUrl(ROOT, process.env.CONTENT_URL);
const AGENTS_URL = resolveAgentsUrl(ROOT, process.env.AGENTS_URL);
const GATEWAY_URL = resolveGatewayUrl(ROOT, process.env.GATEWAY_URL);
const TOKEN = resolveInternalToken(ROOT, process.env.INTERNAL_SERVICE_TOKEN);
const ADMIN_EMAIL = process.env.ADMIN_EMAIL ?? 'admin_local@dgdgd.com';
const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD ?? 'string12';
const ADMIN_ORIGIN = process.env.ADMIN_ORIGIN ?? 'https://admin-phone.bufsa.com';

const SITE_URL = 'https://ezrababait.co.il/';

async function request(method, path, body, headers = {}) {
  const url = `${CONTENT_URL}${path}`;
  const response = await fetch(url, {
    method,
    headers: {
      'Content-Type': 'application/json',
      ...headers,
    },
    body: body ? JSON.stringify(body) : undefined,
    signal: AbortSignal.timeout(20000),
  });
  const text = await response.text();
  let data;
  try {
    data = text ? JSON.parse(text) : null;
  } catch {
    data = text;
  }
  return { status: response.status, data, url };
}

function assertOk(label, result, expectedStatus = 200) {
  if (result.status !== expectedStatus) {
    throw new Error(
      `${label}: HTTP ${result.status} at ${result.url} — ${JSON.stringify(result.data).slice(0, 300)}`,
    );
  }
  console.log(`OK  ${label}`);
  return result.data;
}

function runNpmScript(script) {
  return new Promise((resolve) => {
    const child = spawn(process.platform === 'win32' ? 'npm.cmd' : 'npm', ['run', script], {
      cwd: ROOT,
      stdio: 'inherit',
      shell: process.platform === 'win32',
      env: { ...process.env, CONTENT_URL, AGENTS_URL, INTERNAL_SERVICE_TOKEN: TOKEN },
    });
    child.on('close', (code) => resolve(code === 0));
  });
}

async function main() {
  console.log(`Phone Lab — smoke phase 13 (api-content-prod)\nCONTENT_URL=${CONTENT_URL}\n`);

  console.log('--- P13-1: health ---');
  const live = await request('GET', '/public/api/content/health/live');
  assertOk('health/live', live);
  if (live.data?.status !== 'alive') {
    throw new Error('health/live status not alive');
  }

  const ready = await request('GET', '/public/api/content/health/ready');
  assertOk('health/ready', ready);

  console.log('\n--- P13-2: migrated data (published posts) ---');
  const published = assertOk(
    'published-posts',
    await request(
      'GET',
      '/public/api/content/internal/agent/published-posts',
      null,
      { 'x-internal-service-token': TOKEN },
    ),
  );
  const itemCount = published.items?.length ?? 0;
  if (itemCount < 1) {
    console.warn(`WARN  published-posts has ${itemCount} items (expected >0 after k3s-dev migration)`);
  } else {
    console.log(`OK  published-posts count=${itemCount}`);
  }

  console.log('\n--- P13-3: internal agent bridge ---');
  assertOk(
    'protected-keywords',
    await request(
      'GET',
      '/public/api/content/internal/agent/protected-keywords',
      null,
      { 'x-internal-service-token': TOKEN },
    ),
  );

  const structure = await request(
    'GET',
    '/public/api/content/internal/agent/template-draft/template-builder-test/structure',
    null,
    { 'x-internal-service-token': TOKEN },
  );
  if (structure.status === 200) {
    if (!Array.isArray(structure.data?.sections) || structure.data.sections.length < 1) {
      throw new Error('template-builder-test structure has no sections');
    }
    console.log('OK  template-builder-test structure');
  } else if (structure.status === 404) {
    console.log('OK  template-builder-test not in DB (404 acceptable after dev-only migration)');
  } else {
    throw new Error(`template-builder-test: HTTP ${structure.status}`);
  }

  console.log('\n--- P13-4: content bridge (phase 8 subset) ---');
  const allowlistPut = assertOk(
    'PUT competitor-allowlist',
    await request('PUT', '/public/api/content/seo/competitor-allowlist', {
      siteUrl: SITE_URL,
      domains: ['example-cleaning.co.il'],
      updatedBy: 'smoke-phase13',
    }),
  );
  if (!allowlistPut.domains?.includes('example-cleaning.co.il')) {
    throw new Error('PUT competitor-allowlist missing saved domain');
  }

  const internalAllowlist = assertOk(
    'GET internal competitor-allowlist',
    await request(
      'GET',
      `/public/api/content/internal/agent/competitor-allowlist?siteUrl=${encodeURIComponent(SITE_URL)}`,
      null,
      { 'x-internal-service-token': TOKEN },
    ),
  );
  if (!internalAllowlist.domains?.includes('example-cleaning.co.il')) {
    throw new Error('internal competitor-allowlist roundtrip failed');
  }

  console.log('\n--- P13-5: agents reachable ---');
  try {
    const agentsLive = await fetch(`${AGENTS_URL}/public/api/agents/health/live`, {
      signal: AbortSignal.timeout(8000),
    });
    if (agentsLive.ok) {
      console.log(`OK  agents health at ${AGENTS_URL}`);
    } else {
      console.warn(`WARN  agents health HTTP ${agentsLive.status}`);
    }
  } catch (err) {
    console.warn(`WARN  agents unreachable: ${err.message}`);
  }

  console.log('\n--- P13-6: gateway → content blogs admin ---');
  const loginRes = await fetch(`${GATEWAY_URL}/api/auth/admin/login`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Origin: ADMIN_ORIGIN,
    },
    body: JSON.stringify({
      identifier: ADMIN_EMAIL,
      password: ADMIN_PASSWORD,
    }),
    signal: AbortSignal.timeout(20000),
  });
  if (!loginRes.ok) {
    throw new Error(`admin login HTTP ${loginRes.status}: ${await loginRes.text()}`);
  }
  const cookieHeader = (loginRes.headers.getSetCookie?.() ?? [])
    .map((c) => c.split(';')[0])
    .join('; ');
  if (!cookieHeader) {
    throw new Error('admin login succeeded but no session cookie returned');
  }
  console.log('OK  admin login via gateway');

  const landingViaGw = await fetch(`${GATEWAY_URL}/api/blogs/admin/landing`, {
    headers: { Cookie: cookieHeader },
    signal: AbortSignal.timeout(30000),
  });
  const landingBody = await landingViaGw.text();
  if (landingViaGw.status === 503) {
    throw new Error(
      'gateway blogs/admin/landing returned 503 — restart gateway after CONTENT_INTERNAL_URL change',
    );
  }
  if (!landingViaGw.ok) {
    throw new Error(`gateway blogs/admin/landing HTTP ${landingViaGw.status}: ${landingBody.slice(0, 200)}`);
  }
  let landingJson;
  try {
    landingJson = JSON.parse(landingBody);
  } catch {
    throw new Error('gateway blogs/admin/landing returned non-JSON');
  }
  if (!landingJson?.id) {
    throw new Error('gateway blogs/admin/landing missing landing id');
  }
  console.log('OK  gateway → content blogs/admin/landing');

  console.log('\nPASS  Phone Lab phase 13 smoke');
}

main().catch((err) => {
  console.error(`\nFAIL  ${err.message}`);
  process.exit(1);
});
