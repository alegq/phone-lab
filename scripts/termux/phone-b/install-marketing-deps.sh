#!/data/data/com.termux/files/usr/bin/bash
# One-time deps for api-marketing on Termux (ffmpeg + redis).
set -euo pipefail

echo "=== install marketing deps (Termux) ==="
pkg update -y
pkg install -y ffmpeg redis
echo "OK  ffmpeg=$(command -v ffmpeg)"
echo "OK  redis-server=$(command -v redis-server)"
