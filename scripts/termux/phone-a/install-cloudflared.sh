set -euo pipefail

echo "[cloudflared] Installing prerequisites..."
pkg update -y
pkg install -y curl

echo "[cloudflared] Downloading latest binary..."
ARCH="$(uname -m)"
case "$ARCH" in
  aarch64) CF_ARCH="arm64" ;;
  armv7l|armv8l) CF_ARCH="arm" ;;
  x86_64) CF_ARCH="amd64" ;;
  *)
    echo "Unsupported arch: $ARCH"
    exit 1
    ;;
esac

mkdir -p "$HOME/bin"
curl -fsSL "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${CF_ARCH}" \
  -o "$HOME/bin/cloudflared"
chmod +x "$HOME/bin/cloudflared"

if ! command -v cloudflared >/dev/null 2>&1; then
  echo "[cloudflared] Adding $HOME/bin to PATH for current shell..."
  export PATH="$HOME/bin:$PATH"
fi

echo "[cloudflared] Installed: $(cloudflared --version || true)"

echo
echo "Next steps on phone-a:"
echo "  1) cloudflared tunnel login"
echo "  2) cloudflared tunnel create phone-a-gateway"
echo "  3) mkdir -p ~/phone-lab/cloudflared && cp ~/phone-lab/scripts/cloudflared/phone-a/config.yml.example ~/phone-lab/cloudflared/config.yml"
echo "  4) Edit config.yml: set credentials-file to the generated JSON path"
echo "  5) cloudflared tunnel run --config ~/phone-lab/cloudflared/config.yml"

