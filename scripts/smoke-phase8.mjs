#!/usr/bin/env node
/**
 * Content bridge smoke — api-content-prod internal API + optional agents phase 7.
 *
 * Usage:
 *   npm run smoke:phase8
 *   CONTENT_URL=... INTERNAL_SERVICE_TOKEN=... npm run smoke:phase8
 */

import { spawn } from 'node:child_process';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  resolveContentUrl,
  resolveAgentsUrl,
  resolveInternalToken,
} from './lib/mesh-env.mjs';

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = join(__dirname, '..');

const CONTENT_URL = resolveContentUrl(ROOT, process.env.CONTENT_URL);
const AGENTS_URL = resolveAgentsUrl(ROOT, process.env.AGENTS_URL);
const TOKEN = resolveInternalToken(ROOT, process.env.INTERNAL_SERVICE_TOKEN);

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
    signal: AbortSignal.timeout(15000),
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
      `${label}: HTTP ${result.status} at ${result.url} — ${JSON.stringify(result.data).slice(0, 200)}`,
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

async function agentsReachable() {
  try {
    const res = await fetch(`${AGENTS_URL}/public/api/agents/health/live`, {
      signal: AbortSignal.timeout(5000),
    });
    return res.ok;
  } catch {
    return false;
  }
}

async function main() {
  console.log(`Phone Lab — content bridge smoke\nCONTENT_URL=${CONTENT_URL}\n`);

  console.log('--- Step 1: content-prod health ---');
  const contentOk = await runNpmScript('smoke:content');
  if (!contentOk) {
    throw new Error('smoke:content failed');
  }

  console.log('\n--- Step 2: content bridge ---');
  assertOk(
    'protected-keywords',
    await request(
      'GET',
      '/public/api/content/internal/agent/protected-keywords',
      null,
      { 'x-internal-service-token': TOKEN },
    ),
  );

  const allowlistPut = assertOk(
    'PUT competitor-allowlist',
    await request('PUT', '/public/api/content/seo/competitor-allowlist', {
      siteUrl: SITE_URL,
      domains: ['example-cleaning.co.il'],
      updatedBy: 'smoke-phase8',
    }),
  );
  if (!allowlistPut.domains?.includes('example-cleaning.co.il')) {
    throw new Error('PUT competitor-allowlist missing saved domain');
  }

  const allowlistGet = assertOk(
    'GET competitor-allowlist',
    await request(
      'GET',
      `/public/api/content/seo/competitor-allowlist?siteUrl=${encodeURIComponent(SITE_URL)}`,
    ),
  );
  if (!allowlistGet.domains?.includes('example-cleaning.co.il')) {
    throw new Error('GET competitor-allowlist roundtrip failed');
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
    throw new Error('internal competitor-allowlist missing saved domain');
  }

  const structure = assertOk(
    'template-builder-test structure',
    await request(
      'GET',
      '/public/api/content/internal/agent/template-draft/template-builder-test/structure',
      null,
      { 'x-internal-service-token': TOKEN },
    ),
  );
  if (!Array.isArray(structure.sections) || structure.sections.length < 1) {
    throw new Error('template-builder-test structure has no sections');
  }

  const snapshot = assertOk(
    'POST gsc/snapshots',
    await request(
      'POST',
      '/public/api/content/internal/agent/gsc/snapshots',
      {
        siteUrl: SITE_URL,
        gscProperty: 'sc-domain:ezrababait.co.il',
        locale: 'he',
        snapshotDate: new Date().toISOString().slice(0, 10),
        rows: [
          {
            query: 'cleaning tel aviv',
            clicks: 10,
            impressions: 100,
            ctr: 0.1,
            position: 5.2,
          },
        ],
        sourceRunId: 'smoke-phase8',
      },
      { 'x-internal-service-token': TOKEN },
    ),
    200,
  );
  if (!snapshot.snapshotId) {
    throw new Error('gsc/snapshots missing snapshotId');
  }

  const metrics = assertOk(
    'GET gsc/metrics',
    await request(
      'GET',
      `/public/api/content/internal/agent/gsc/metrics?siteUrl=${encodeURIComponent(SITE_URL)}&locale=he`,
      null,
      { 'x-internal-service-token': TOKEN },
    ),
  );
  if (!Array.isArray(metrics.metrics) || metrics.metrics.length < 1) {
    throw new Error('gsc/metrics returned no rows');
  }

  console.log('\n--- Step 3: agents phase 7 (optional) ---');
  if (await agentsReachable()) {
    console.log(`AGENTS_URL=${AGENTS_URL} reachable — running smoke:phase7`);
    const phase7Ok = await runNpmScript('smoke:phase7');
    if (!phase7Ok) {
      throw new Error('smoke:phase7 failed (agents online but workflow/health failed)');
    }
  } else {
    console.warn(`WARN  AGENTS_URL=${AGENTS_URL} unreachable — skipping smoke:phase7`);
  }

  console.log('\nPASS  Phone Lab content bridge smoke');
}

main().catch((err) => {
  console.error(`\nFAIL  ${err.message}`);
  process.exit(1);
});
