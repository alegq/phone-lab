#!/usr/bin/env python3
"""Upload a file to phone-a or phone-b via SFTP."""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

try:
    import paramiko
except ImportError:
    print("Install: python -m pip install --user paramiko", file=sys.stderr)
    raise SystemExit(1)

from mesh_config import phone_target
from ssh_exec import connect


def resolve_remote_path(sftp, client, remote: str) -> str:
    if not remote.startswith("~/") and remote != "~":
        return remote
    _, stdout, _ = client.exec_command('printf %s "$HOME"')
    home = stdout.read().decode("utf-8", errors="replace").strip()
    if not home:
        raise SystemExit("Could not resolve remote HOME")
    if remote == "~":
        return home
    return f"{home}/{remote[2:]}"


def main() -> None:
    parser = argparse.ArgumentParser(description="Upload file to phone via SFTP")
    parser.add_argument("phone", help="phone-a or phone-b")
    parser.add_argument("local", help="local file path")
    parser.add_argument("remote", help="remote path on phone")
    args = parser.parse_args()

    local = Path(args.local).resolve()
    if not local.is_file():
        raise SystemExit(f"Local file not found: {local}")

    target = phone_target(args.phone)
    client = connect(target)
    try:
        sftp = client.open_sftp()
        remote_path = resolve_remote_path(sftp, client, args.remote)
        sftp.put(str(local), remote_path)
        sftp.close()
        print(f"Uploaded {local.name} -> {remote_path}")
    finally:
        client.close()


if __name__ == "__main__":
    main()
