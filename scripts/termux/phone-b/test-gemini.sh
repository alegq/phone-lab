#!/data/data/com.termux/files/usr/bin/bash
# Test Gemini API reachability from phone-b (same SDK as api-agents).
set -euo pipefail

PKG_DIR="${PKG_DIR:-$HOME/phone-lab/packages/api-agents-prod}"
ENV_FILE="$PKG_DIR/.env"
NODE="/data/data/com.termux/files/usr/bin/node"

if [ ! -f "$ENV_FILE" ]; then
  echo "ERROR: $ENV_FILE not found"
  exit 1
fi

# shellcheck disable=SC1090
set -a
source "$ENV_FILE"
set +a

if [ "${LLM_STUB:-true}" = "true" ]; then
  echo "ERROR: LLM_STUB=true — switch to live profile first"
  exit 1
fi

if [ -z "${GEMINI_API_KEY:-}" ]; then
  echo "ERROR: GEMINI_API_KEY empty in $ENV_FILE"
  exit 1
fi

cd "$PKG_DIR" || exit 1

"$NODE" - <<'NODE'
const { GoogleGenAI } = require('@google/genai');

const apiKey = process.env.GEMINI_API_KEY;
const model = 'gemini-2.5-flash';

(async () => {
  const genAI = new GoogleGenAI({ apiKey });
  const response = await genAI.models.generateContent({
    model,
    contents: [{ parts: [{ text: 'Reply with exactly: pong' }] }],
    config: { maxOutputTokens: 16 },
  });
  const reply = response?.text?.trim() ?? '';
  if (!reply) {
    console.error('Empty Gemini response');
    process.exit(1);
  }
  console.log(`OK  Gemini reachable from phone-b via SDK (reply=${reply.slice(0, 40)})`);
})().catch((err) => {
  const msg = err?.message ?? String(err);
  console.error(`Gemini SDK failed: ${msg}`);
  if (/location is not supported|FAILED_PRECONDITION/i.test(msg)) {
    console.error('HINT: Gemini region block — try VPN on phone-b or rollback stub profile');
  }
  process.exit(1);
});
NODE
