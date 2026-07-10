#!/usr/bin/env python3
"""Deploy PC SSH public key to phone-a / phone-b and ensure sshd is running."""
from __future__ import annotations

import os
import sys
from pathlib import Path

try:
    import paramiko
except ImportError:
    print("Install: python -m pip install --user paramiko", file=sys.stderr)
    raise SystemExit(1)

from mesh_config import phone_target

PUBKEY = Path(os.path.expanduser("~/.ssh/phone-lab.pub"))
BOOT_SSHD = """#!/data/data/com.termux/files/usr/bin/bash
pgrep -x sshd >/dev/null || sshd
"""


def run(client: paramiko.SSHClient, command: str) -> tuple[int, str, str]:
    _, stdout, stderr = client.exec_command(command)
    code = stdout.channel.recv_exit_status()
    out = stdout.read().decode("utf-8", errors="replace")
    err = stderr.read().decode("utf-8", errors="replace")
    return code, out, err


def connect(target: dict) -> paramiko.SSHClient:
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    kwargs: dict = {
        "hostname": target["host"],
        "port": target["port"],
        "username": target["user"],
        "timeout": 20,
    }
    identity = Path(target["identity"])
    if identity.with_suffix(".pub").is_file() and identity.is_file():
        try:
            client.connect(**kwargs, key_filename=str(identity), look_for_keys=False, allow_agent=False)
            return client
        except paramiko.AuthenticationException:
            pass
    if not target["password"]:
        raise SystemExit(f"No SSH key and no PHONE_SSH_PASSWORD for {target['name']}")
    client.connect(**kwargs, password=target["password"], look_for_keys=False, allow_agent=False)
    return client


def install_key(target_name: str) -> None:
    if not PUBKEY.is_file():
        raise SystemExit(f"Missing public key: {PUBKEY}\nRun: ssh-keygen -t ed25519 -f ~/.ssh/phone-lab -N \"\"")

    pubkey = PUBKEY.read_text(encoding="utf-8").strip()
    target = phone_target(target_name)
    print(f"=== {target['name']} ({target['user']}@{target['host']}:{target['port']}) ===")

    client = connect(target)
    try:
        cmd = (
            "mkdir -p ~/.ssh && chmod 700 ~/.ssh && "
            f"grep -qF '{pubkey}' ~/.ssh/authorized_keys 2>/dev/null || "
            f"echo '{pubkey}' >> ~/.ssh/authorized_keys && "
            "chmod 600 ~/.ssh/authorized_keys && "
            "mkdir -p ~/.termux/boot && "
            f"cat > ~/.termux/boot/start-sshd.sh <<'EOF'\n{BOOT_SSHD}EOF\n"
            "chmod +x ~/.termux/boot/start-sshd.sh && "
            "(pgrep -x sshd >/dev/null || sshd) && "
            "whoami"
        )
        code, out, err = run(client, cmd)
        if code != 0:
            print(err or out, file=sys.stderr)
            raise SystemExit(code)
        print(f"  user: {out.strip()}")
        print("  key installed, sshd running, boot script updated")
    finally:
        client.close()


def main() -> None:
    targets = sys.argv[1:] or ["phone-a", "phone-b"]
    for name in targets:
        install_key(name)
    print("\nTest from PC:")
    print("  ssh -i ~/.ssh/phone-lab -p 8022 <user>@<tailscale-ip> whoami")


if __name__ == "__main__":
    main()
