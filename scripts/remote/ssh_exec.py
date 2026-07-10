#!/usr/bin/env python3
"""Run a shell command on phone-a or phone-b via Termux SSH."""
from __future__ import annotations

import argparse
import shlex
import sys
from pathlib import Path

try:
    import paramiko
except ImportError:
    print("Install: python -m pip install --user paramiko", file=sys.stderr)
    raise SystemExit(1)

from mesh_config import phone_target


def connect(target: dict, timeout: int = 30) -> paramiko.SSHClient:
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    kwargs = {
        "hostname": target["host"],
        "port": target["port"],
        "username": target["user"],
        "timeout": timeout,
    }
    identity = Path(target["identity"])
    if identity.is_file():
        try:
            client.connect(**kwargs, key_filename=str(identity), look_for_keys=False, allow_agent=False)
            return client
        except paramiko.AuthenticationException:
            pass
    if not target["password"]:
        raise SystemExit(f"SSH auth failed for {target['name']} — run: python scripts/remote/setup_ssh_keys.py")
    client.connect(**kwargs, password=target["password"], look_for_keys=False, allow_agent=False)
    return client


def main() -> None:
    parser = argparse.ArgumentParser(description="Run command on phone via SSH")
    parser.add_argument("phone", help="phone-a or phone-b")
    parser.add_argument("command", nargs=argparse.REMAINDER, help="shell command")
    parser.add_argument("--timeout", type=int, default=30, help="SSH connect timeout (seconds)")
    args = parser.parse_args()
    if not args.command:
        raise SystemExit("command required")

    command = " ".join(args.command).strip()
    target = phone_target(args.phone)
    client = connect(target, timeout=args.timeout)
    try:
        _, stdout, stderr = client.exec_command(f"bash -lc {shlex.quote(command)}")
        out = stdout.read().decode("utf-8", errors="replace")
        err = stderr.read().decode("utf-8", errors="replace")
        code = stdout.channel.recv_exit_status()
        if out:
            sys.stdout.write(out)
            if not out.endswith("\n"):
                sys.stdout.write("\n")
        if err:
            sys.stderr.write(err)
            if not err.endswith("\n"):
                sys.stderr.write("\n")
        raise SystemExit(code)
    finally:
        client.close()


if __name__ == "__main__":
    main()
