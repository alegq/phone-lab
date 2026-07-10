#!/usr/bin/env node
/**
 * Phase 0 mesh verification — ping phone-a and phone-b from dev PC.
 *
 * Usage:
 *   copy mesh.env.example mesh.env   # fill Tailscale IPs
 *   npm run verify:mesh
 *
 * Reads mesh.env from repo root. Tries ICMP ping, then tailscale ping as fallback.
 */

import { execFile } from 'node:child_process';
import { readFileSync, existsSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { promisify } from 'node:util';

const execFileAsync = promisify(execFile);
const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = join(__dirname, '..');
const MESH_ENV = join(ROOT, 'mesh.env');

const isWindows = process.platform === 'win32';

/**
 * Parse simple KEY=VALUE lines from mesh.env (no quotes, no export).
 */
function loadMeshEnv(path) {
  if (!existsSync(path)) {
    console.error(`ERROR: ${path} not found.`);
    console.error('  copy mesh.env.example mesh.env');
    console.error('  Fill PHONE_A_IP and PHONE_B_IP with Tailscale IPv4 addresses.');
    process.exit(1);
  }

  const vars = {};
  const content = readFileSync(path, 'utf8');
  for (const line of content.split('\n')) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const eq = trimmed.indexOf('=');
    if (eq === -1) continue;
    const key = trimmed.slice(0, eq).trim();
    const value = trimmed.slice(eq + 1).trim();
    vars[key] = value;
  }
  return vars;
}

/**
 * Basic Tailscale IPv4 check (100.64.0.0/10 CGNAT range used by Tailscale).
 */
function isPlausibleTailscaleIp(ip) {
  if (!ip || !/^\d{1,3}(\.\d{1,3}){3}$/.test(ip)) return false;
  const parts = ip.split('.').map(Number);
  if (parts.some((p) => p > 255)) return false;
  // Tailscale assigns from 100.64.0.0/10
  return parts[0] === 100 && parts[1] >= 64 && parts[1] <= 127;
}

/**
 * ICMP ping — Windows: ping -n count -w timeout_ms
 */
async function icmpPing(ip, count = 2, timeoutMs = 3000) {
  try {
    if (isWindows) {
      const { stdout } = await execFileAsync('ping', ['-n', String(count), '-w', String(timeoutMs), ip], {
        timeout: timeoutMs * count + 5000,
      });
      const received = (stdout.match(/TTL=/gi) || []).length;
      return received > 0;
    }
    const timeoutSec = Math.ceil(timeoutMs / 1000);
    const { stdout } = await execFileAsync('ping', ['-c', String(count), '-W', String(timeoutSec), ip], {
      timeout: timeoutMs * count + 5000,
    });
    return /bytes from/i.test(stdout) || /\d+ received/i.test(stdout);
  } catch {
    return false;
  }
}

/**
 * tailscale ping — works when ICMP is blocked on target.
 */
async function tailscalePing(target) {
  try {
    const { stdout, stderr } = await execFileAsync('tailscale', ['ping', '-c', '2', target], {
      timeout: 15000,
    });
    const out = stdout + stderr;
    return /pong from/i.test(out) || /latency/i.test(out);
  } catch {
    return false;
  }
}

async function tailscaleCliAvailable() {
  try {
    await execFileAsync('tailscale', ['version'], { timeout: 5000 });
    return true;
  } catch {
    return false;
  }
}

/**
 * Verify one device by IP and optional MagicDNS hostname.
 */
async function verifyDevice(label, ip, hostname, hasTailscale) {
  const issues = [];

  if (!ip) {
    console.log(`FAIL  ${label}: IP not set in mesh.env`);
    return false;
  }

  if (!isPlausibleTailscaleIp(ip)) {
    issues.push(`IP ${ip} does not look like Tailscale 100.64.x.x–100.127.x.x`);
  }

  process.stdout.write(`CHECK ${label} (${ip}) ... `);

  let ok = await icmpPing(ip);
  let method = 'icmp';

  if (!ok && hasTailscale && hostname) {
    ok = await tailscalePing(hostname);
    method = ok ? 'tailscale-ping' : method;
  }

  if (!ok && hasTailscale) {
    ok = await tailscalePing(ip);
    method = ok ? 'tailscale-ping' : method;
  }

  if (ok) {
    console.log(`OK (${method})`);
  } else {
    console.log('FAIL');
    console.log(`       → Ensure Tailscale is Connected on ${label}`);
    console.log(`       → Try: tailscale ping ${hostname || ip}`);
  }

  for (const msg of issues) {
    console.log(`WARN  ${label}: ${msg}`);
  }

  return ok;
}

async function main() {
  console.log('Phone Lab — mesh verification (Phase 0)\n');

  const env = loadMeshEnv(MESH_ENV);
  const phoneA = env.PHONE_A_IP;
  const phoneB = env.PHONE_B_IP;
  const devPc = env.DEV_PC_IP;
  const hostnameA = env.PHONE_A_HOSTNAME || 'phone-a';
  const hostnameB = env.PHONE_B_HOSTNAME || 'phone-b';

  const hasTailscale = await tailscaleCliAvailable();
  if (hasTailscale) {
    console.log('Tailscale CLI: available\n');
  } else {
    console.log('Tailscale CLI: not found (using ICMP ping only)\n');
  }

  const results = [];

  if (devPc) {
    console.log(`INFO  DEV_PC_IP=${devPc} (informational, not pinged)\n`);
  } else {
    console.log('WARN  DEV_PC_IP not set in mesh.env (optional)\n');
  }

  results.push(await verifyDevice('phone-a', phoneA, hostnameA, hasTailscale));
  results.push(await verifyDevice('phone-b', phoneB, hostnameB, hasTailscale));

  console.log('');
  const passed = results.filter(Boolean).length;
  const total = results.length;

  if (passed === total) {
    console.log(`PASS  ${passed}/${total} devices reachable`);
    console.log('\nPhase 0 acceptance met. Update docs/DEVICE-REGISTRY.md → status: online');
    process.exit(0);
  }

  console.log(`FAIL  ${passed}/${total} devices reachable`);
  console.log('\nSee docs/PHASE-0-SETUP.md and docs/TROUBLESHOOTING.md');
  process.exit(1);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
