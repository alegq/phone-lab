#!/usr/bin/env node
/**
 * Phase 10 smoke — smoke-local.mjs --full against phone-b (live Gemini).
 *
 * Usage:
 *   npm run smoke:phase10
 *
 * Env (optional overrides):
 *   AGENTS_URL, CONTENT_URL, INTERNAL_SERVICE_TOKEN
 */

import { spawn } from 'node:child_process';
import { existsSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  resolveAgentsUrl,
  resolveContentUrl,
  resolveInternalToken,
} from './lib/mesh-env.mjs';
import { loadMeshSecrets } from './lib/mesh-secrets.mjs';

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = join(__dirname, '..');
const SMOKE_LOCAL = join(ROOT, '..', 'api-agents', 'scripts', 'smoke-local.mjs');
const SMOKE_TIMEOUT_MS = 55 * 60 * 1000;

const AGENTS_URL = resolveAgentsUrl(ROOT, process.env.AGENTS_URL);
const CONTENT_URL = resolveContentUrl(ROOT, process.env.CONTENT_URL);
const TOKEN = resolveInternalToken(ROOT, process.env.INTERNAL_SERVICE_TOKEN);

async function request(method, url, body) {
  const response = await fetch(url, {
    method,
    headers: { 'Content-Type': 'application/json' },
    body: body ? JSON.stringify(body) : undefined,
    signal: AbortSignal.timeout(30000),
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

async function preflight() {
  console.log(`Phone Lab — smoke phase 10 (smoke-local --full)\n`);
  console.log(`  AGENTS_URL=${AGENTS_URL}`);
  console.log(`  CONTENT_URL=${CONTENT_URL}`);
  console.log(`  TOKEN=${TOKEN ? '(set)' : '(missing)'}\n`);

  const secrets = loadMeshSecrets(ROOT);
  if (!secrets.GEMINI_API_KEY?.trim()) {
    throw new Error('GEMINI_API_KEY missing in mesh.secrets.env — required for phase 10');
  }

  assertOk(
    'agents health/ready',
    await request('GET', `${AGENTS_URL}/public/api/agents/health/ready`),
  );

  assertOk(
    'content health/live',
    await request('GET', `${CONTENT_URL}/public/api/content/health/live`),
  );

  if (TOKEN) {
    const pkRes = await fetch(
      `${CONTENT_URL}/public/api/content/internal/agent/protected-keywords`,
      {
        headers: { 'x-internal-service-token': TOKEN },
        signal: AbortSignal.timeout(15000),
      },
    );
    const pkText = await pkRes.text();
    let pkData;
    try {
      pkData = pkText ? JSON.parse(pkText) : null;
    } catch {
      pkData = pkText;
    }
    assertOk('content protected-keywords', {
      status: pkRes.status,
      data: pkData,
      url: pkRes.url,
    });
  }
}

function runSmokeLocalFull() {
  return new Promise((resolve, reject) => {
    if (!existsSync(SMOKE_LOCAL)) {
      reject(new Error(`smoke-local.mjs not found: ${SMOKE_LOCAL}`));
      return;
    }

    console.log('\nStarting api-agents/scripts/smoke-local.mjs --full');
    console.log('Expected duration: 30–60 minutes. Keep phone-b on charger.\n');

    const child = spawn(process.execPath, [SMOKE_LOCAL, '--full'], {
      cwd: join(ROOT, '..', 'api-agents'),
      env: {
        ...process.env,
        AGENTS_URL,
        CONTENT_URL,
        INTERNAL_SERVICE_TOKEN: TOKEN,
      },
      stdio: 'inherit',
    });

    const timer = setTimeout(() => {
      child.kill('SIGTERM');
      reject(new Error(`smoke-local --full timed out after ${SMOKE_TIMEOUT_MS / 60000} min`));
    }, SMOKE_TIMEOUT_MS);

    child.on('error', reject);
    child.on('close', (code) => {
      clearTimeout(timer);
      if (code === 0) resolve();
      else reject(new Error(`smoke-local --full exited with code ${code}`));
    });
  });
}

async function main() {
  await preflight();
  await runSmokeLocalFull();
  console.log('\nPASS  smoke:phase10');
}

main().catch((err) => {
  console.error(`\nFAIL  smoke:phase10 — ${err.message}`);
  process.exit(1);
});
