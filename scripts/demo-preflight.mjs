#!/usr/bin/env node
/**
 * Pre-demo / mesh self-check — verify:mesh + prod smoke + URLs.
 *
 * Usage:
 *   npm run demo:preflight
 */

import { spawn } from 'node:child_process';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  loadMeshEnv,
  agentsUrlFromMesh,
  gatewayUrlFromMesh,
} from './lib/mesh-env.mjs';

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = join(__dirname, '..');

function runNpmScript(script) {
  return new Promise((resolve) => {
    const child = spawn(process.platform === 'win32' ? 'npm.cmd' : 'npm', ['run', script], {
      cwd: ROOT,
      stdio: 'inherit',
      shell: process.platform === 'win32',
    });
    child.on('close', (code) => resolve(code === 0));
  });
}

async function main() {
  console.log('Phone Lab — mesh preflight\n');

  const mesh = loadMeshEnv(ROOT);
  const agentsUrl = agentsUrlFromMesh(mesh) || 'http://127.0.0.1:4010';
  const gatewayUrl = gatewayUrlFromMesh(mesh) || 'http://127.0.0.1:4000';

  console.log('--- URLs ---');
  console.log(`GATEWAY_URL=${gatewayUrl}`);
  console.log(`AGENTS_URL=${agentsUrl}`);
  console.log(`HEALTH=${gatewayUrl}/api/health/live\n`);

  console.log('--- Step 1: mesh ---');
  const meshOk = await runNpmScript('verify:mesh');
  if (!meshOk) {
    console.error('\nFAIL  mesh preflight — mesh unreachable');
    process.exit(1);
  }

  console.log('\n--- Step 2: prod smoke ---');
  const smokeOk = await runNpmScript('smoke');
  if (!smokeOk) {
    console.error('\nFAIL  mesh preflight — smoke failed');
    console.error('MIUI manual boot reminder (after reboot):');
    console.error('  phone-b: bash ~/.termux/boot/start-phone-b-stack.sh');
    console.error('  phone-a: bash ~/phone-lab/scripts/termux/phone-a/boot-gateway-phone-a.sh');
    process.exit(1);
  }

  console.log('\n--- Ready ---');
  console.log('Gateway health:', gatewayUrl + '/api/health/live');
  console.log('Agents health:', agentsUrl + '/public/api/agents/health/live');
  console.log('Logs on phone-a: tail ~/phone-lab/logs/gateway-prod.log');
  console.log('\nPASS  mesh preflight');
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
