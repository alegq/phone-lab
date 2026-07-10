/**
 * Load mesh.secrets.env (gitignored) for Phone Lab deploy/smoke scripts.
 */

import { readFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';

/**
 * Parse simple KEY=VALUE lines from mesh.secrets.env.
 * @param {string} root - phone-lab repo root
 * @returns {Record<string, string>}
 */
export function loadMeshSecrets(root) {
  const secretsPath = join(root, 'mesh.secrets.env');
  if (!existsSync(secretsPath)) {
    return {};
  }

  const vars = {};
  const content = readFileSync(secretsPath, 'utf8');
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
 * @param {string} root
 * @param {string} key
 * @param {string} [fallback]
 */
export function getMeshSecret(root, key, fallback = '') {
  const secrets = loadMeshSecrets(root);
  return secrets[key]?.trim() || fallback;
}
