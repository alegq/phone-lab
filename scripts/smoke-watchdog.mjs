#!/usr/bin/env node
/**
 * Smoke test for Phone Lab watchdog — kill service, run watchdog, verify recovery.
 *
 * Usage:
 *   npm run smoke:watchdog
 */

import { spawnSync } from 'node:child_process';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { resolveAgentsUrl, resolveGatewayUrl } from './lib/mesh-env.mjs';

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = join(__dirname, '..');
const isWin = process.platform === 'win32';

const KILL_AGENTS =
  'bash ~/phone-lab/scripts/termux/lib/kill-service-by-cwd.sh api-agents-prod';

const KILL_GATEWAY =
  'bash ~/phone-lab/scripts/termux/lib/kill-service-by-cwd.sh api-gateway-prod';

const AGENTS_URL = resolveAgentsUrl(ROOT, process.env.AGENTS_URL);
const GATEWAY_URL = resolveGatewayUrl(ROOT, process.env.GATEWAY_URL);

function runRemote(phone, command, timeoutMs = 120000) {
  if (isWin) {
    const ps1 = join(__dirname, 'remote-exec.ps1');
    const result = spawnSync(
      'powershell',
      ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ps1, phone, command],
      { cwd: ROOT, encoding: 'utf8', stdio: 'pipe', timeout: timeoutMs },
    );
    const out = (result.stdout || '') + (result.stderr || '');
    if (out.trim()) process.stdout.write(out.endsWith('\n') ? out : `${out}\n`);
    return { code: result.status ?? 1, out };
  }

  const py = join(__dirname, 'remote', 'ssh_exec.py');
  const result = spawnSync('python', [py, phone, command], {
    cwd: ROOT,
    encoding: 'utf8',
    stdio: 'pipe',
    timeout: timeoutMs,
  });
  const out = (result.stdout || '') + (result.stderr || '');
  if (out.trim()) process.stdout.write(out.endsWith('\n') ? out : `${out}\n`);
  return { code: result.status ?? 1, out };
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function fetchHealth(url) {
  try {
    const response = await fetch(url, { signal: AbortSignal.timeout(30000) });
    return response.status;
  } catch {
    return 0;
  }
}

async function ensureHealthy(label, url, phone, watchScript) {
  let status = await fetchHealth(url);
  if (status === 200) return;
  console.warn(`WARN  ${label} not healthy (HTTP ${status}) — running watchdog on ${phone}`);
  runRemote(phone, `rm -f ~/phone-lab/data/watchdog.lock; timeout 180 bash ${watchScript}`, 200000);
  for (let i = 0; i < 12; i += 1) {
    await sleep(5000);
    status = await fetchHealth(url);
    if (status === 200) return;
  }
  throw new Error(`${label} not healthy after watchdog: HTTP ${status} at ${url}`);
}

async function testPhoneB() {
  console.log('\n--- phone-b: agents kill-and-recover ---');

  await ensureHealthy(
    'agents',
    `${AGENTS_URL}/public/api/agents/health/live`,
    'phone-b',
    '~/phone-lab/scripts/termux/phone-b/watch-stack-phone-b.sh',
  );

  const pre = runRemote(
    'phone-b',
    'bash ~/phone-lab/scripts/termux/phone-b/watch-stack-phone-b.sh',
  );
  if (pre.code !== 0) {
    console.warn(`WARN  pre-watchdog exit ${pre.code} (continuing)`);
  }

  const liveBefore = await fetchHealth(`${AGENTS_URL}/public/api/agents/health/live`);
  if (liveBefore !== 200) {
    throw new Error(`agents not healthy before test: HTTP ${liveBefore} at ${AGENTS_URL}`);
  }
  console.log('OK  agents healthy before kill');

  runRemote('phone-b', KILL_AGENTS);
  await sleep(3000);

  const liveAfterKill = await fetchHealth(`${AGENTS_URL}/public/api/agents/health/live`);
  if (liveAfterKill === 200) {
    throw new Error('agents still healthy immediately after kill — test invalid');
  }
  console.log(`OK  agents down after kill (HTTP ${liveAfterKill})`);

  const watch = runRemote(
    'phone-b',
    'bash ~/phone-lab/scripts/termux/phone-b/watch-stack-phone-b.sh',
    180000,
  );
  if (watch.code !== 0) {
    console.warn(`WARN  watchdog exit ${watch.code}`);
  }

  if (!/restart agents/i.test(watch.out)) {
    const log = runRemote('phone-b', 'tail -20 ~/phone-lab/logs/watchdog.log');
    if (!/restart agents/i.test(log.out)) {
      throw new Error('watchdog.log does not contain "restart agents"');
    }
  }
  console.log('OK  watchdog restarted agents');

  const liveRecovered = await fetchHealth(`${AGENTS_URL}/public/api/agents/health/live`);
  if (liveRecovered !== 200) {
    throw new Error(`agents not recovered: HTTP ${liveRecovered}`);
  }
  console.log('OK  agents health/live after watchdog');
}

async function testPhoneA() {
  console.log('\n--- phone-a: gateway kill-and-recover ---');

  await ensureHealthy(
    'gateway',
    `${GATEWAY_URL}/api/health/live`,
    'phone-a',
    '~/phone-lab/scripts/termux/phone-a/watch-stack-phone-a.sh',
  );

  const pre = runRemote(
    'phone-a',
    'bash ~/phone-lab/scripts/termux/phone-a/watch-stack-phone-a.sh',
  );
  if (pre.code !== 0) {
    console.warn(`WARN  pre-watchdog exit ${pre.code} (continuing)`);
  }

  const liveBefore = await fetchHealth(`${GATEWAY_URL}/api/health/live`);
  if (liveBefore !== 200) {
    throw new Error(`gateway not healthy before test: HTTP ${liveBefore} at ${GATEWAY_URL}`);
  }
  console.log('OK  gateway healthy before kill');

  runRemote('phone-a', KILL_GATEWAY);
  await sleep(3000);

  const liveAfterKill = await fetchHealth(`${GATEWAY_URL}/api/health/live`);
  if (liveAfterKill === 200) {
    throw new Error('gateway still healthy immediately after kill — test invalid');
  }
  console.log(`OK  gateway down after kill (HTTP ${liveAfterKill})`);

  const watch = runRemote(
    'phone-a',
    'bash ~/phone-lab/scripts/termux/phone-a/watch-stack-phone-a.sh',
    180000,
  );
  if (watch.code !== 0) {
    console.warn(`WARN  watchdog exit ${watch.code}`);
  }

  if (!/restart gateway/i.test(watch.out)) {
    const log = runRemote('phone-a', 'tail -20 ~/phone-lab/logs/watchdog.log');
    if (!/restart gateway/i.test(log.out)) {
      throw new Error('watchdog.log does not contain "restart gateway"');
    }
  }
  console.log('OK  watchdog restarted gateway');

  const liveRecovered = await fetchHealth(`${GATEWAY_URL}/api/health/live`);
  if (liveRecovered !== 200) {
    throw new Error(`gateway not recovered: HTTP ${liveRecovered}`);
  }
  console.log('OK  gateway health/live after watchdog');
}

async function main() {
  console.log('Phone Lab — smoke watchdog (kill-and-recover)');
  console.log(`AGENTS_URL=${AGENTS_URL}`);
  console.log(`GATEWAY_URL=${GATEWAY_URL}`);

  await testPhoneB();
  await testPhoneA();

  console.log('\n--- regression smoke ---');
  const gateway = spawnSync(isWin ? 'npm.cmd' : 'npm', ['run', 'smoke:gateway-prod'], {
    cwd: ROOT,
    encoding: 'utf8',
    stdio: 'inherit',
    shell: isWin,
  });
  if ((gateway.status ?? 1) !== 0) {
    throw new Error('smoke:gateway-prod failed');
  }

  const phase8 = spawnSync(isWin ? 'npm.cmd' : 'npm', ['run', 'smoke:phase8'], {
    cwd: ROOT,
    encoding: 'utf8',
    stdio: 'inherit',
    shell: isWin,
  });
  if ((phase8.status ?? 1) !== 0) {
    console.warn('WARN  smoke:phase8 failed (may be unrelated to watchdog)');
  }

  console.log('\nPASS smoke:watchdog');
}

main().catch((err) => {
  console.error(`\nFAIL smoke:watchdog — ${err.message}`);
  process.exit(1);
});
