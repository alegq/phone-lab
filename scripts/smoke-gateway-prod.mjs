#!/usr/bin/env node
/**
 * Phase 9 smoke — prod api-gateway on phone-a (health only).
 *
 * Usage:
 *   npm run smoke:gateway-prod
 *   GATEWAY_URL=http://100.120.187.10:4000 npm run smoke:gateway-prod
 *
 * Does NOT call /api/agents/admin/* (api-auth phase next).
 */

import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { resolveGatewayUrl } from './lib/mesh-env.mjs';

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = join(__dirname, '..');

const GATEWAY_URL = resolveGatewayUrl(ROOT, process.env.GATEWAY_URL);

async function request(path) {
  const url = `${GATEWAY_URL}${path}`;
  const response = await fetch(url, { signal: AbortSignal.timeout(30000) });
  const text = await response.text();
  let data;
  try {
    data = text ? JSON.parse(text) : null;
  } catch {
    data = text;
  }
  return { status: response.status, data, url };
}

function assertOk(label, result, check) {
  if (result.status !== 200) {
    throw new Error(
      `${label}: HTTP ${result.status} at ${result.url} — ${JSON.stringify(result.data).slice(0, 200)}`,
    );
  }
  if (!check(result.data)) {
    throw new Error(`${label}: unexpected body ${JSON.stringify(result.data).slice(0, 200)}`);
  }
  console.log(`OK  ${label}`);
}

async function main() {
  console.log(`Phone Lab — smoke api-gateway-prod (phase 9)\nGATEWAY_URL=${GATEWAY_URL}\n`);

  const startup = await request('/api/health/startup');
  assertOk('api/health/startup', startup, (d) => d?.status === 'ok');

  const live = await request('/api/health/live');
  assertOk('api/health/live', live, (d) => d?.status === 'alive');

  const ready = await request('/api/health/ready');
  assertOk('api/health/ready', ready, (d) => d?.status === 'ok' && d?.info?.memory_heap?.status === 'up');

  console.log('\nPASS  api-gateway-prod smoke (P9-1..P9-3)');
}

main().catch((err) => {
  console.error(`\nFAIL  ${err.message}`);
  process.exit(1);
});
