#!/usr/bin/env node
/**
 * Phase 14 smoke — OpenClaw gateway on phone-a + factory regression.
 *
 * Usage:
 *   npm run smoke:phase14
 *   OPENCLAW_URL=http://100.120.187.10:18789 npm run smoke:phase14
 *
 * Requires mesh.openclaw.env with OPENCLAW_ENABLED=1 after deploy.
 * If OPENCLAW_SSH_TUNNEL=1, starts SSH tunnel to phone-a loopback gateway.
 */

import { spawn } from 'node:child_process';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  loadMeshEnv,
  loadMeshOpenclaw,
  isOpenclawEnabled,
  resolveOpenclawUrl,
  resolveAgentsUrl,
  resolveGatewayUrl,
} from './lib/mesh-env.mjs';

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = join(__dirname, '..');

let tunnelChild = null;

function cleanup() {
  if (tunnelChild && !tunnelChild.killed) {
    tunnelChild.kill('SIGTERM');
  }
}

process.on('exit', cleanup);
process.on('SIGINT', () => {
  cleanup();
  process.exit(130);
});

async function request(url, path) {
  const full = `${url.replace(/\/$/, '')}${path}`;
  const response = await fetch(full, { signal: AbortSignal.timeout(30000) });
  const text = await response.text();
  let data;
  try {
    data = text ? JSON.parse(text) : null;
  } catch {
    data = text;
  }
  return { status: response.status, data, url: full };
}

function assertOk(label, result) {
  if (result.status !== 200) {
    throw new Error(
      `${label}: HTTP ${result.status} at ${result.url} — ${JSON.stringify(result.data).slice(0, 200)}`,
    );
  }
  console.log(`OK  ${label}`);
}

function startSshTunnel(mesh, openclaw) {
  const meshEnv = loadMeshEnv(ROOT);
  const phoneIp = openclaw.OPENCLAW_PHONE_A_IP || meshEnv.PHONE_A_IP;
  const sshUser = meshEnv.PHONE_A_SSH_USER || process.env.PHONE_A_SSH_USER;
  const sshPort = meshEnv.PHONE_SSH_PORT || '8022';
  const localPort = openclaw.OPENCLAW_LOCAL_PORT || openclaw.OPENCLAW_PORT || '18789';
  const remotePort = openclaw.OPENCLAW_PORT || '18789';

  if (!phoneIp || !sshUser) {
    throw new Error('OPENCLAW_SSH_TUNNEL=1 requires PHONE_A_IP and PHONE_A_SSH_USER in mesh.env');
  }

  const args = [
    '-N',
    '-L',
    `${localPort}:127.0.0.1:${remotePort}`,
    '-p',
    sshPort,
    `${sshUser}@${phoneIp}`,
  ];

  console.log(`Starting SSH tunnel localhost:${localPort} -> phone-a:127.0.0.1:${remotePort}`);
  tunnelChild = spawn('ssh', args, { stdio: 'ignore' });
  return new Promise((resolve, reject) => {
    const timer = setTimeout(resolve, 2500);
    tunnelChild.on('error', (err) => {
      clearTimeout(timer);
      reject(err);
    });
    tunnelChild.on('exit', (code) => {
      if (code !== null && code !== 0) {
        clearTimeout(timer);
        reject(new Error(`SSH tunnel exited with code ${code}`));
      }
    });
  });
}

async function main() {
  if (!isOpenclawEnabled(ROOT) && !process.env.OPENCLAW_URL) {
    console.log('SKIP  smoke:phase14 — set OPENCLAW_ENABLED=1 in mesh.openclaw.env or OPENCLAW_URL');
    process.exit(0);
  }

  const openclawCfg = loadMeshOpenclaw(ROOT);
  const agentsUrl = resolveAgentsUrl(ROOT, process.env.AGENTS_URL);
  const gatewayUrl = resolveGatewayUrl(ROOT, process.env.GATEWAY_URL);

  if (openclawCfg.OPENCLAW_SSH_TUNNEL === '1' && !process.env.OPENCLAW_URL) {
    await startSshTunnel(loadMeshEnv(ROOT), openclawCfg);
  }

  const openclawUrl = resolveOpenclawUrl(ROOT, process.env.OPENCLAW_URL);

  console.log(`Phone Lab — smoke Phase 14 (OpenClaw)\n`);
  console.log(`OPENCLAW_URL=${openclawUrl}`);
  console.log(`AGENTS_URL=${agentsUrl}`);
  console.log(`GATEWAY_URL=${gatewayUrl}\n`);

  const ocHealth = await request(openclawUrl, '/health');
  assertOk('P14-1 openclaw /health', ocHealth);

  const agentsLive = await request(agentsUrl, '/public/api/agents/health/live');
  assertOk('P14-2 agents health/live', agentsLive);

  const gwLive = await request(gatewayUrl, '/api/health/live');
  assertOk('P14-3 gateway health/live', gwLive);

  console.log('\nPASS  smoke:phase14 (P14-1..P14-3; run demo:preflight for P14-5)');
}

main().catch((err) => {
  console.error(`\nFAIL  ${err.message}`);
  cleanup();
  process.exit(1);
});
