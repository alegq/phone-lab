#!/usr/bin/env node
/**
 * Phase 11 smoke — verify gateway → api-auth (Rabbit) → agents admin proxy.
 *
 * Runs api-agents/scripts/verify-gateway-agents.mjs against phone-a gateway.
 *
 * Usage:
 *   npm run smoke:phase11
 *
 * Optional env overrides:
 *   GATEWAY_URL, ADMIN_EMAIL, ADMIN_PASSWORD, ADMIN_ORIGIN
 */

import { spawn } from 'node:child_process';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { resolveGatewayUrl } from './lib/mesh-env.mjs';

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = join(__dirname, '..');
const VERIFY = join(ROOT, '..', 'api-agents', 'scripts', 'verify-gateway-agents.mjs');

const GATEWAY_URL = resolveGatewayUrl(ROOT, process.env.GATEWAY_URL);
const ADMIN_EMAIL = process.env.ADMIN_EMAIL ?? 'admin_local@dgdgd.com';
const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD ?? 'string12';
const ADMIN_ORIGIN = process.env.ADMIN_ORIGIN ?? 'http://localhost:5173';

async function request(url) {
  const res = await fetch(url, { signal: AbortSignal.timeout(15000) });
  const text = await res.text();
  let data;
  try {
    data = text ? JSON.parse(text) : null;
  } catch {
    data = text;
  }
  return { status: res.status, data, url };
}

function assertOk(label, result, expectedStatus = 200) {
  if (result.status !== expectedStatus) {
    throw new Error(`${label}: HTTP ${result.status} at ${result.url} — ${JSON.stringify(result.data).slice(0, 200)}`);
  }
  console.log(`OK  ${label}`);
}

function runRemoteExec(phone, cmd) {
  return new Promise((resolve, reject) => {
    const ps = process.platform === 'win32' ? 'powershell' : 'pwsh';
    const child = spawn(
      ps,
      [
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        join(ROOT, 'scripts', 'remote-exec.ps1'),
        phone,
        cmd,
      ],
      { cwd: ROOT, stdio: ['ignore', 'pipe', 'pipe'] },
    );
    let out = '';
    let err = '';
    child.stdout.on('data', (d) => (out += d.toString()));
    child.stderr.on('data', (d) => (err += d.toString()));
    child.on('close', (code) => {
      if (code === 0) resolve({ out, err });
      else reject(new Error(`remote-exec ${phone} failed (${code}): ${err || out}`));
    });
  });
}

async function main() {
  console.log('Phone Lab — smoke phase 11 (gateway admin via auth)\n');
  console.log(`  GATEWAY_URL=${GATEWAY_URL}`);
  console.log(`  ADMIN_EMAIL=${ADMIN_EMAIL}`);
  console.log(`  ADMIN_ORIGIN=${ADMIN_ORIGIN}\n`);

  assertOk('gateway health/live', await request(`${GATEWAY_URL}/api/health/live`));

  // Verify cross-phone AMQP reachability from phone-a to phone-b (best signal).
  await runRemoteExec('phone-a', "timeout 5 bash -lc 'echo > /dev/tcp/100.103.183.36/5672' && echo AMQP_OK");
  console.log('OK  phone-a -> phone-b:5672');

  console.log('\nRunning verify-gateway-agents.mjs (admin login + proxy)...\n');

  await new Promise((resolve, reject) => {
    const child = spawn(process.execPath, [VERIFY], {
      cwd: join(ROOT, '..', 'api-agents'),
      env: {
        ...process.env,
        GATEWAY_URL,
        ADMIN_EMAIL,
        ADMIN_PASSWORD,
        ADMIN_ORIGIN,
        SKIP_BLOG: process.env.SKIP_BLOG ?? '1',
      },
      stdio: 'inherit',
    });
    child.on('close', (code) => {
      if (code === 0) resolve();
      else reject(new Error(`verify-gateway-agents failed (${code}). If login fails, seed admin (Firebase user + auth DB row) and retry.`));
    });
  });

  console.log('\nPASS  Phone Lab phase 11 smoke');
}

main().catch((e) => {
  console.error(`\nFAIL  ${e.message}`);
  process.exit(1);
});

