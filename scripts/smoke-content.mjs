#!/usr/bin/env node
/**
 * Smoke checks for api-content-prod.
 *
 * Usage:
 *   npm run smoke:content
 *   CONTENT_URL=http://127.0.0.1:4004 npm run smoke:content
 */

import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { resolveContentUrl } from './lib/mesh-env.mjs';

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = join(__dirname, '..');

const CONTENT_URL = resolveContentUrl(ROOT, process.env.CONTENT_URL);

async function request(path) {
  const url = `${CONTENT_URL}${path}`;
  const response = await fetch(url, {
    signal: AbortSignal.timeout(10000),
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

function assertOk(label, result, check) {
  if (result.status !== 200) {
    throw new Error(`${label}: HTTP ${result.status} at ${result.url}`);
  }
  if (!check(result.data)) {
    throw new Error(`${label}: unexpected body ${JSON.stringify(result.data)}`);
  }
  console.log(`OK  ${label}`);
}

async function main() {
  console.log(`Phone Lab — smoke api-content-prod\nCONTENT_URL=${CONTENT_URL}\n`);

  const live = await request('/public/api/content/health/live');
  assertOk('health/live', live, (d) => d?.status === 'alive');

  const ready = await request('/public/api/content/health/ready');
  assertOk('health/ready', ready, (d) => d?.status === 'ok' || d?.status === 'alive');

  console.log('\nPASS  api-content-prod smoke');
}

main().catch((err) => {
  console.error(`\nFAIL  ${err.message}`);
  process.exit(1);
});
