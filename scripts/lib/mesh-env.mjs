/**
 * Shared mesh.env loader for Phone Lab smoke scripts.
 */

import { readFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';

/**
 * Parse simple KEY=VALUE lines from mesh.env (no quotes, no export).
 * @param {string} root - phone-lab repo root
 * @returns {Record<string, string>}
 */
export function loadMeshEnv(root) {
  const meshEnvPath = join(root, 'mesh.env');
  if (!existsSync(meshEnvPath)) {
    return {};
  }

  const vars = {};
  const content = readFileSync(meshEnvPath, 'utf8');
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
 * @param {Record<string, string>} env
 * @returns {string|null}
 */
export function agentsUrlFromMesh(env) {
  const ip = env.PHONE_B_IP;
  return ip ? `http://${ip}:4010` : null;
}

/**
 * @param {Record<string, string>} env
 * @returns {string|null}
 */
export function gatewayUrlFromMesh(env) {
  const ip = env.PHONE_A_IP;
  return ip ? `http://${ip}:4000` : null;
}

/**
 * Resolve agents URL from env override or mesh.env.
 * @param {string} root
 * @param {string} [envOverride]
 * @param {string} [fallback]
 */
export function resolveAgentsUrl(root, envOverride, fallback = 'http://127.0.0.1:4010') {
  const fromEnv = envOverride?.replace(/\/$/, '');
  if (fromEnv) return fromEnv;
  const mesh = loadMeshEnv(root);
  return (agentsUrlFromMesh(mesh) || fallback).replace(/\/$/, '');
}

/**
 * Resolve gateway URL from env override or mesh.env.
 * @param {string} root
 * @param {string} [envOverride]
 * @param {string} [fallback]
 */
export function resolveGatewayUrl(root, envOverride, fallback = 'http://127.0.0.1:4000') {
  const fromEnv = envOverride?.replace(/\/$/, '');
  if (fromEnv) return fromEnv;
  const mesh = loadMeshEnv(root);
  return (gatewayUrlFromMesh(mesh) || fallback).replace(/\/$/, '');
}

/**
 * @param {Record<string, string>} env
 * @returns {string|null}
 */
export function contentUrlFromMesh(env) {
  const phoneB = env.PHONE_B_IP;
  return phoneB ? `http://${phoneB}:4004` : null;
}

function loadMeshContent(root) {
  const meshContentPath = join(root, 'mesh.content.env');
  if (!existsSync(meshContentPath)) {
    return {};
  }
  const vars = {};
  const content = readFileSync(meshContentPath, 'utf8');
  for (const line of content.split('\n')) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const eq = trimmed.indexOf('=');
    if (eq === -1) continue;
    vars[trimmed.slice(0, eq).trim()] = trimmed.slice(eq + 1).trim();
  }
  return vars;
}

/**
 * Resolve content URL from env override or mesh.env.
 * @param {string} root
 * @param {string} [envOverride]
 * @param {string} [fallback]
 */
export function resolveContentUrl(root, envOverride, fallback = 'http://127.0.0.1:4004') {
  const fromEnv = envOverride?.replace(/\/$/, '');
  if (fromEnv) return fromEnv;
  const meshContent = loadMeshContent(root);
  if (meshContent.CONTENT_IP) return `http://${meshContent.CONTENT_IP}:4004`;
  const mesh = loadMeshEnv(root);
  return (contentUrlFromMesh(mesh) || fallback).replace(/\/$/, '');
}

/**
 * @param {Record<string, string>} env
 * @returns {string|null}
 */
export function marketingUrlFromMesh(env) {
  const ip = env.MARKETING_IP;
  if (ip) return `http://${ip}:4008`;
  const phoneB = env.PHONE_B_IP;
  return phoneB ? `http://${phoneB}:4008` : null;
}

/**
 * Resolve marketing URL from env override, mesh.marketing.env, or mesh.env.
 * @param {string} root
 * @param {string} [envOverride]
 * @param {string} [fallback]
 */
export function resolveMarketingUrl(root, envOverride, fallback = 'http://127.0.0.1:4008') {
  const fromEnv = envOverride?.replace(/\/$/, '');
  if (fromEnv) return fromEnv;

  const meshMarketingPath = join(root, 'mesh.marketing.env');
  if (existsSync(meshMarketingPath)) {
    const mm = {};
    const content = readFileSync(meshMarketingPath, 'utf8');
    for (const line of content.split('\n')) {
      const trimmed = line.trim();
      if (!trimmed || trimmed.startsWith('#')) continue;
      const eq = trimmed.indexOf('=');
      if (eq === -1) continue;
      mm[trimmed.slice(0, eq).trim()] = trimmed.slice(eq + 1).trim();
    }
    if (mm.MARKETING_IP) return `http://${mm.MARKETING_IP}:4008`;
  }

  const mesh = loadMeshEnv(root);
  return (marketingUrlFromMesh(mesh) || fallback).replace(/\/$/, '');
}

/**
 * Load mesh.secrets.env (INTERNAL_SERVICE_TOKEN, SSH password).
 * @param {string} root
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
 * Resolve INTERNAL_SERVICE_TOKEN from env or mesh.secrets.env.
 * @param {string} root
 * @param {string} [envOverride]
 */
export function resolveInternalToken(root, envOverride) {
  const fromEnv = envOverride?.trim();
  if (fromEnv) return fromEnv;
  const secrets = loadMeshSecrets(root);
  if (secrets.INTERNAL_SERVICE_TOKEN) return secrets.INTERNAL_SERVICE_TOKEN;
  return 'phone-lab-internal-token';
}
