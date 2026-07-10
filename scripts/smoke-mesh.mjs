#!/usr/bin/env node
/**
 * Combined mesh smoke — prod gateway + prod agents health.
 *
 * Usage:
 *   npm run smoke
 *   AGENTS_URL=... GATEWAY_URL=... npm run smoke
 */

import { spawn } from 'node:child_process';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = join(__dirname, '..');

function runNpmScript(script) {
  return new Promise((resolve) => {
    const child = spawn(process.platform === 'win32' ? 'npm.cmd' : 'npm', ['run', script], {
      cwd: ROOT,
      stdio: 'inherit',
      shell: process.platform === 'win32',
      env: process.env,
    });
    child.on('close', (code) => resolve(code === 0));
  });
}

async function main() {
  console.log('Phone Lab — combined mesh smoke\n');

  const gatewayOk = await runNpmScript('smoke:gateway-prod');
  if (!gatewayOk) {
    throw new Error('smoke:gateway-prod failed');
  }

  const agentsOk = await runNpmScript('smoke:phase7');
  if (!agentsOk) {
    throw new Error('smoke:phase7 failed');
  }

  console.log('\nPASS  Phone Lab combined mesh smoke');
}

main().catch((err) => {
  console.error(`\nFAIL  ${err.message}`);
  process.exit(1);
});
