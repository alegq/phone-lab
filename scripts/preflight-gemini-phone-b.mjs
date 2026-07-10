#!/usr/bin/env node
/**
 * Phase 10 preflight — verify live Gemini on phone-b agents.
 *
 * Usage:
 *   npm run preflight:gemini
 */

import { spawnSync } from 'node:child_process';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { loadMeshSecrets } from './lib/mesh-secrets.mjs';
import { resolveAgentsUrl } from './lib/mesh-env.mjs';

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = join(__dirname, '..');
const isWin = process.platform === 'win32';
const AGENTS_URL = resolveAgentsUrl(ROOT, process.env.AGENTS_URL);
const agentsAdmin = `${AGENTS_URL}/public/api/agents/agents/admin`;

function runRemote(command) {
  if (isWin) {
    const ps1 = join(__dirname, 'remote-exec.ps1');
    const result = spawnSync(
      'powershell',
      ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ps1, 'phone-b', command],
      { cwd: ROOT, encoding: 'utf8', stdio: 'pipe' },
    );
    const out = (result.stdout || '') + (result.stderr || '');
    if (out.trim()) process.stdout.write(out.endsWith('\n') ? out : `${out}\n`);
    return result.status ?? 1;
  }

  const py = join(__dirname, 'remote', 'ssh_exec.py');
  const result = spawnSync('python', [py, 'phone-b', command], {
    cwd: ROOT,
    encoding: 'utf8',
    stdio: 'pipe',
  });
  const out = (result.stdout || '') + (result.stderr || '');
  if (out.trim()) process.stdout.write(out.endsWith('\n') ? out : `${out}\n`);
  return result.status ?? 1;
}

async function request(method, url, body) {
  const response = await fetch(url, {
    method,
    headers: { 'Content-Type': 'application/json' },
    body: body ? JSON.stringify(body) : undefined,
    signal: AbortSignal.timeout(60000),
  });
  const text = await response.text();
  let data;
  try {
    data = text ? JSON.parse(text) : null;
  } catch {
    data = text;
  }
  return { status: response.status, data };
}

async function pollRun(runId, timeoutMs = 120000) {
  const started = Date.now();
  while (Date.now() - started < timeoutMs) {
    const detail = await request('GET', `${agentsAdmin}/runs/${runId}`);
    if (detail.status !== 200) {
      throw new Error(`get run ${runId}: HTTP ${detail.status}`);
    }
    const status = detail.data?.status;
    if (['completed', 'failed', 'cancelled', 'waiting_approval'].includes(status)) {
      return detail.data;
    }
    await new Promise((r) => setTimeout(r, 2000));
  }
  throw new Error(`Timeout polling run ${runId}`);
}

async function main() {
  console.log('Phone Lab — preflight Gemini (phone-b)\n');
  console.log(`  AGENTS_URL=${AGENTS_URL}\n`);

  const secrets = loadMeshSecrets(ROOT);
  if (!secrets.GEMINI_API_KEY?.trim()) {
    console.error('ERROR: GEMINI_API_KEY missing in mesh.secrets.env');
    process.exit(1);
  }

  console.log('Checking agents .env on phone-b...');
  const grepCode = runRemote(
    "grep -E '^LLM_STUB=' ~/phone-lab/packages/api-agents-prod/.env 2>/dev/null; grep '^GEMINI_API_KEY=' ~/phone-lab/packages/api-agents-prod/.env 2>/dev/null | sed 's/=.*/=***/' || echo 'MISSING .env'",
  );
  if (grepCode !== 0) {
    console.error('ERROR: cannot read agents .env on phone-b. Is SSH configured?');
    process.exit(1);
  }

  const ready = await request('GET', `${AGENTS_URL}/public/api/agents/health/ready`);
  if (ready.status !== 200) {
    console.error(`ERROR: agents health/ready HTTP ${ready.status}`);
    process.exit(1);
  }
  console.log('OK  agents health/ready');

  console.log('\nOptional: test-gemini.sh on phone-b (SDK direct)...');
  const testScript =
    '$HOME/phone-lab/packages/api-agents-prod/scripts/termux/phone-b/test-gemini.sh';
  const sdkCode = runRemote(`bash ${testScript}`);
  if (sdkCode === 0) {
    console.log('\nPASS  Gemini preflight (phone-b SDK)');
    return;
  }
  console.warn('WARN  phone-b SDK ping failed — trying agents LLM workflow...');

  const started = await request('POST', `${agentsAdmin}/runs`, {
    workflowKey: 'blog_content_generation',
    basePrompt: 'One sentence about tidy homes.',
  });
  if (started.status !== 200 && started.status !== 201) {
    console.error(`ERROR: start blog_content_generation HTTP ${started.status}`);
    process.exit(1);
  }
  const runId = started.data?.id;
  if (!runId) {
    console.error('ERROR: missing run id');
    process.exit(1);
  }

  const run = await pollRun(runId);
  const err = String(run.errorMessage ?? run.error ?? '');
  if (/location is not supported|FAILED_PRECONDITION/i.test(err)) {
    console.error('\nFAIL  Gemini region block on phone-b');
    console.error('Options: VPN on phone-b, or rollback: apply-phone-b-env.ps1 -Profile stub');
    process.exit(1);
  }
  if (['waiting_approval', 'completed'].includes(run.status)) {
    console.log(`\nPASS  Gemini preflight via agents (run ${runId} → ${run.status})`);
    return;
  }

  console.error(`\nFAIL  blog_content_generation ended: ${run.status} — ${err || 'unknown'}`);
  process.exit(1);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
