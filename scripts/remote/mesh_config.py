"""Load mesh.env + mesh.secrets.env for phone-lab remote scripts."""
from __future__ import annotations

import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def _parse_env_file(path: Path) -> dict[str, str]:
    data: dict[str, str] = {}
    if not path.is_file():
        return data
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        data[key.strip()] = value.strip()
    return data


def load_mesh() -> dict[str, str]:
    env = {}
    env.update(_parse_env_file(ROOT / "mesh.env.example"))
    env.update(_parse_env_file(ROOT / "mesh.env"))
    env.update(_parse_env_file(ROOT / "mesh.secrets.env"))
    return env


def phone_target(name: str) -> dict[str, str]:
    mesh = load_mesh()
    key = name.lower().replace("_", "-")
    aliases = {
        "phone-a": "a",
        "phone-a-gateway": "a",
        "a": "a",
        "phone-b": "b",
        "phone-b-agents": "b",
        "b": "b",
    }
    suffix = aliases.get(key)
    if not suffix:
        raise SystemExit(f"Unknown phone target: {name!r} (use phone-a or phone-b)")

    return {
        "name": f"phone-{suffix}",
        "host": mesh[f"PHONE_{suffix.upper()}_IP"],
        "user": mesh[f"PHONE_{suffix.upper()}_SSH_USER"],
        "port": int(mesh.get("PHONE_SSH_PORT", "8022")),
        "password": mesh.get("PHONE_SSH_PASSWORD", ""),
        "identity": os.path.expanduser(mesh.get("PHONE_SSH_IDENTITY", "~/.ssh/phone-lab")),
    }
