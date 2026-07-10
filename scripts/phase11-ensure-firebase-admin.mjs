#!/usr/bin/env node
/**
 * Phase 11 helper — ensure Firebase Auth user exists and print its localId (uid).
 *
 * Uses Firebase Identity Toolkit REST API with FIREBASE_API_KEY.
 *
 * Env:
 *   FIREBASE_API_KEY (required)
 *   ADMIN_EMAIL (default: admin_local@dgdgd.com)
 *   ADMIN_PASSWORD (default: string12)
 */

const FIREBASE_API_KEY = process.env.FIREBASE_API_KEY?.trim();
const ADMIN_EMAIL = process.env.ADMIN_EMAIL ?? 'admin_local@dgdgd.com';
const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD ?? 'string12';

if (!FIREBASE_API_KEY) {
  console.error('FIREBASE_API_KEY missing');
  process.exit(2);
}

async function postJson(url, body) {
  const res = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
    signal: AbortSignal.timeout(30000),
  });
  const text = await res.text();
  let data;
  try {
    data = text ? JSON.parse(text) : null;
  } catch {
    data = text;
  }
  return { ok: res.ok, status: res.status, data };
}

async function signIn() {
  const url = `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${FIREBASE_API_KEY}`;
  return postJson(url, {
    email: ADMIN_EMAIL,
    password: ADMIN_PASSWORD,
    returnSecureToken: true,
  });
}

async function signUp() {
  const url = `https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${FIREBASE_API_KEY}`;
  return postJson(url, {
    email: ADMIN_EMAIL,
    password: ADMIN_PASSWORD,
    returnSecureToken: true,
  });
}

async function main() {
  let res = await signIn();
  if (!res.ok) {
    const msg = res?.data?.error?.message;
    if (msg === 'EMAIL_NOT_FOUND') {
      const create = await signUp();
      if (!create.ok) {
        throw new Error(`Firebase signUp failed HTTP ${create.status}: ${JSON.stringify(create.data)}`);
      }
      res = await signIn();
    } else {
      throw new Error(`Firebase signIn failed HTTP ${res.status}: ${JSON.stringify(res.data)}`);
    }
  }

  const uid = res?.data?.localId;
  if (!uid) throw new Error('Firebase response missing localId');

  process.stdout.write(uid);
}

main().catch((e) => {
  console.error(e.message);
  process.exit(1);
});

