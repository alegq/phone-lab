#!/usr/bin/env python3
"""Sync phone-b Termux scripts and run proot/Rabbit stack steps via SSH."""
from __future__ import annotations

import argparse
import shlex
import stat
import sys
from pathlib import Path

try:
    import paramiko
except ImportError:
    print("Install: python -m pip install --user paramiko", file=sys.stderr)
    raise SystemExit(1)

from mesh_config import ROOT, phone_target
from ssh_exec import connect

REMOTE_STACK_REL = "phone-lab/packages/api-agents-prod/scripts/termux/phone-b"
LOCAL_SCRIPTS = ROOT / "scripts" / "termux" / "phone-b"


def upload_scripts(phone: str) -> str:
    target = phone_target(phone)
    client = connect(target, timeout=60)
    try:
        _, stdout, _ = client.exec_command('printf %s "$HOME"')
        home = stdout.read().decode("utf-8", errors="replace").strip()
        if not home:
            raise SystemExit("empty remote HOME")
        remote_stack = f"{home}/{REMOTE_STACK_REL}"

        sftp = client.open_sftp()
        parts = remote_stack.strip("/").split("/")
        path = ""
        for part in parts:
            path = f"{path}/{part}" if path else f"/{part}"
            try:
                sftp.stat(path)
            except OSError:
                sftp.mkdir(path)

        for local in sorted(LOCAL_SCRIPTS.glob("*.sh")):
            remote = f"{remote_stack}/{local.name}"
            sftp.put(str(local), remote)
            sftp.chmod(remote, stat.S_IRWXU | stat.S_IRGRP | stat.S_IXGRP | stat.S_IROTH | stat.S_IXOTH)
            print(f"  uploaded {local.name}")
        sftp.close()
        return remote_stack
    finally:
        client.close()


def run_remote(phone: str, command: str, timeout: int) -> int:
    target = phone_target(phone)
    client = connect(target, timeout=min(timeout, 120))
    try:
        transport = client.get_transport()
        if transport:
            transport.set_keepalive(30)
        _, stdout, stderr = client.exec_command(f"bash -lc {shlex.quote(command)}", timeout=timeout)
        out = stdout.read().decode("utf-8", errors="replace")
        err = stderr.read().decode("utf-8", errors="replace")
        code = stdout.channel.recv_exit_status()
        if out:
            safe = out.encode(sys.stdout.encoding or "utf-8", errors="replace").decode(
                sys.stdout.encoding or "utf-8", errors="replace"
            )
            sys.stdout.write(safe)
            if not safe.endswith("\n"):
                sys.stdout.write("\n")
        if err:
            safe_err = err.encode(sys.stderr.encoding or "utf-8", errors="replace").decode(
                sys.stderr.encoding or "utf-8", errors="replace"
            )
            sys.stderr.write(safe_err)
            if not safe_err.endswith("\n"):
                sys.stderr.write("\n")
        return code
    finally:
        client.close()


def main() -> None:
    parser = argparse.ArgumentParser(description="Deploy phone-b stack scripts via SSH")
    parser.add_argument("--phone", default="phone-b", help="phone-a or phone-b")
    parser.add_argument(
        "--action",
        choices=["upload", "proot", "rabbit", "verify", "boot", "full"],
        default="upload",
        help="upload scripts only, or run setup steps",
    )
    parser.add_argument("--timeout", type=int, default=3600, help="command timeout seconds")
    args = parser.parse_args()

    print(f"=== deploy_phone_b_stack: {args.action} ===")

    if args.action in ("upload", "proot", "rabbit", "verify", "boot", "full"):
        print("Uploading scripts...")
        stack = upload_scripts(args.phone)
    else:
        stack = ""

    if args.action == "upload":
        print("\n=== deploy_phone_b_stack: done ===")
        return

    print(f"Remote stack: {stack}")

    steps: list[tuple[str, str, int]] = []
    if args.action == "proot":
        steps = [(f"bash {stack}/setup-proot-debian.sh", "setup-proot-debian", 3600)]
    elif args.action == "rabbit":
        steps = [(f"bash {stack}/setup-rabbit-proot.sh", "setup-rabbit-proot", 1800)]
    elif args.action == "verify":
        steps = [(f"bash {stack}/verify-rabbit-proot.sh", "verify-rabbit-proot", 300)]
    elif args.action == "boot":
        steps = [
            (f"bash {stack}/boot-stack-phone-b.sh", "boot-stack-phone-b", 600),
            (f"bash {stack}/install-boot-stack.sh", "install-boot-stack", 120),
        ]
    elif args.action == "full":
        steps = [
            (f"bash {stack}/setup-proot-debian.sh", "setup-proot-debian", 3600),
            (f"bash {stack}/setup-rabbit-proot.sh", "setup-rabbit-proot", 1800),
            (f"bash {stack}/verify-rabbit-proot.sh", "verify-rabbit-proot", 300),
            (f"pkg uninstall -y rabbitmq-server erlang 2>/dev/null || true", "uninstall-termux-rabbit", 300),
            (f"bash {stack}/boot-stack-phone-b.sh", "boot-stack-phone-b", 600),
            (f"bash {stack}/install-boot-stack.sh", "install-boot-stack", 120),
            (f"bash {stack}/verify-rabbit-proot.sh", "verify-rabbit-proot", 300),
        ]

    for command, label, timeout in steps:
        print(f"\n--- {label} (timeout {timeout}s) ---")
        code = run_remote(args.phone, command, timeout=min(timeout, args.timeout))
        if code != 0:
            raise SystemExit(code)

    print("\n=== deploy_phone_b_stack: done ===")


if __name__ == "__main__":
    main()
