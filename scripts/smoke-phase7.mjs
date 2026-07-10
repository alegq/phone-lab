#!/usr/bin/env node
/**
 * Phase 7 smoke — prod api-agents on phone-b.
 *
 * Usage:
 *   npm run smoke:phase7
 *   AGENTS_URL=http://100.103.183.36:4010 npm run smoke:phase7
 *
 * Checks: health/live, health/ready, test_durable_workflow run → completed.
 */

import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { resolveAgentsUrl } from './lib/mesh-env.mjs';

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = join(__dirname, '..');

const AGENTS_URL = resolveAgentsUrl(ROOT, process.env.AGENTS_URL);
const agentsAdmin = `${AGENTS_URL}/public/api/agents/agents/admin`;
const POLL_MS = 2000;
const POLL_TIMEOUT_MS = 120000;

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
    throw new Error(`${label}: HTTP ${result.status} at ${result.url} — ${JSON.stringify(result.data).slice(0, 200)}`);
  }
  console.log(`OK  ${label}`);
  return result.data;
}

async function pollRun(runId) {
  const started = Date.now();
  while (Date.now() - started < POLL_TIMEOUT_MS) {
    const detail = await request('GET', `${agentsAdmin}/runs/${runId}`);
    assertOk(`get run ${runId}`, detail);
    const status = detail.data.status;
    process.stdout.write(`    run ${runId} status=${status}\r`);
    if (['completed', 'failed', 'cancelled'].includes(status)) {
      console.log(`\n    run ${runId} finished: ${status}`);
      return detail.data;
    }
    await new Promise((r) => setTimeout(r, POLL_MS));
  }
  throw new Error(`Timeout waiting for run ${runId}`);
}

async function main() {
  console.log(`Phone Lab — smoke phase 7 (prod api-agents)\nAGENTS_URL=${AGENTS_URL}\n`);

  const live = await request('GET', `${AGENTS_URL}/public/api/agents/health/live`);
  assertOk('health/live', live);
  if (live.data?.status !== 'alive') {
    throw new Error('health/live: expected status alive');
  }

  const ready = await request('GET', `${AGENTS_URL}/public/api/agents/health/ready`);
  assertOk('health/ready', ready);

  const started = assertOk(
    'start test_durable_workflow',
    await request('POST', `${agentsAdmin}/runs`, {
      workflowKey: 'test_durable_workflow',
      message: 'phone-lab phase7',
    }),
    201,
  );

  const run = await pollRun(started.id);
  if (run.status !== 'completed') {
    throw new Error(`test_durable_workflow ended with ${run.status}: ${run.errorMessage || run.error || ''}`);
  }
  console.log('OK  test_durable_workflow completed');

  console.log('\nPASS  Phone Lab phase 7 smoke');
}

main().catch((err) => {
  console.error(`\nFAIL  ${err.message}`);
  process.exit(1);
});
