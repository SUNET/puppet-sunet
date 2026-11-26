#!/usr/bin/python3
"""Inspect one immutable local Podman image without starting any image code."""

import argparse
import difflib
import hashlib
import json
import os
import re
import shutil
import stat
import subprocess
import sys
import urllib.request
from pathlib import Path

import yaml


def podman(*args):
    return subprocess.check_output(["podman", *map(str, args)])


def manifest_digest(tag):
    official = re.fullmatch(r"docker\.io/library/([a-z0-9_-]+):([\w.-]+)", tag)
    if official:
        registries = json.loads(podman("info", "--format", "{{json .Registries}}"))
        # Let containers/image resolve blocked, mirrored and remapped names.
        if not any("*" in prefix or tag.startswith(prefix) for prefix in registries):
            name, version = official.groups()
            url = f"https://hub.docker.com/v2/namespaces/library/repositories/{name}/tags/{version}"
            try:
                with urllib.request.urlopen(url, timeout=12) as response:
                    info = json.load(response)
                if info["name"] == version and re.fullmatch(r"sha256:[a-f0-9]{64}", info["digest"]):
                    return info["digest"]
            except (OSError, ValueError, KeyError):
                pass  # Use the site's normal registry client on metadata-service failures.
    raw = subprocess.check_output(["skopeo", "inspect", "--raw", "docker://" + tag])
    return "sha256:" + hashlib.sha256(raw).hexdigest()


def stage(tag, platform):
    ref = tag.rsplit(":", 1)[0] + "@" + manifest_digest(tag)
    if subprocess.run(["podman", "image", "exists", ref]).returncode == 0:
        local = json.loads(podman("image", "inspect", ref))[0]
        if local["Os"] + "/" + local["Architecture"] == platform and ref in local["RepoDigests"]:
            return local["Id"]
    return podman("pull", "-q", "--platform", platform, ref).decode().strip().splitlines()[-1]


def resolve(root, path):
    """Resolve absolute and relative image symlinks relative to the image root."""
    if not path.startswith("/"):
        raise ValueError(f"expected absolute image path: {path}")
    parts = []
    queue = path.split("/")
    links = 0
    while queue:
        item = queue.pop(0)
        if item in ("", "."):
            continue
        if item == "..":
            if parts:
                parts.pop()
            continue
        target = root.joinpath(*parts, item)
        if target.is_symlink():
            links += 1
            if links > 40:
                raise ValueError(f"symlink loop at {path}")
            dest = os.readlink(target)
            if dest.startswith("/"):
                parts.clear()
            queue = dest.split("/") + queue
        else:
            parts.append(item)
    return "/" + "/".join(parts)


def mounted(action, image):
    root = Path(podman("image", "mount", image).decode().strip())
    try:
        action(root)
    finally:
        podman("image", "unmount", image)


def read_image(root, request):
    if "copy" in request:
        target = root / resolve(root, request["copy"]).lstrip("/")
        with target.open("rb") as stream:
            shutil.copyfileobj(stream, sys.stdout.buffer)
        return
    rows = []
    for entry in request["executables"]:
        path = resolve(root, entry["path"])
        target = root / path.lstrip("/")
        mode = target.stat().st_mode
        if not stat.S_ISREG(mode) or not mode & 0o111:
            raise ValueError(f"{path} must be a regular executable")
        with target.open("rb") as stream:
            header = stream.readline(256)
        row = {**entry, "target": path}
        row.pop("interpreter", None)
        row["alias_targets"] = {alias: resolve(root, alias) for alias in row.get("aliases", [])}
        if header.startswith(b"#!"):
            shebang = header[2:].decode().strip().split()
            interp = resolve(root, shebang[0])
            row["interpreter"] = [interp, *shebang[1:]]
        elif not header.startswith(b"\x7fELF"):
            raise ValueError(f"{path} has no ELF header or shebang")
        rows.append(row)
    inputs = {}
    for path in request.get("reviewed_files", {}):
        canonical = resolve(root, path)
        file = root / canonical.lstrip("/")
        if not file.is_file():
            raise ValueError(f"expected regular file at {path}")
        inputs[path] = {"target": canonical}
    print(json.dumps({"executables": rows, **({"reviewed_files": inputs} if inputs else {})}))


def drop_legacy_file_hashes(profile):
    # Older site profiles can still be present when the module tag advances.
    for entry in profile["executables"]:
        entry.pop("sha256", None)
    for entry in profile.get("reviewed_files", {}).values():
        entry.pop("sha256", None)


def inspect(profile, identity):
    info = json.loads(podman("image", "inspect", identity))[0]
    image_id = info["Id"]
    config = info["Config"]
    # Include environment and image volume declarations in the comparison without
    # printing their values. PATH, PGDATA and loader settings can change startup.
    metadata = {
        key: config.get(key)
        for key in (
            "Entrypoint",
            "Cmd",
            "User",
            "WorkingDir",
            "Healthcheck",
            "StopSignal",
            "Volumes",
            "Env",
            "Shell",
            "OnBuild",
        )
    }
    contract = {key: metadata[key] for key in ("Entrypoint", "Cmd", "User", "WorkingDir")}
    contract["config_sha256"] = hashlib.sha256(json.dumps(metadata, sort_keys=True).encode()).hexdigest()
    result = subprocess.check_output(
        ["podman", "unshare", sys.executable, __file__, "_read", image_id], input=json.dumps(profile).encode()
    )
    return {
        **profile,
        "platform": info["Os"] + "/" + info["Architecture"],
        "startup": contract,
        **json.loads(result),
    }


def dump(profile):
    return yaml.safe_dump(profile, sort_keys=False, width=110)


def main():
    if len(sys.argv) == 4 and sys.argv[1] == "_stage":
        print(stage(sys.argv[2], sys.argv[3]))
        return
    if len(sys.argv) == 3 and sys.argv[1] == "_read":
        request = json.load(sys.stdin)
        mounted(lambda root: read_image(root, request), sys.argv[2])
        return
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("profile", type=Path)
    p.add_argument("--image", help="local candidate ID or reference (default: profile tag)")
    p.add_argument("--emit", action="store_true", help="write proposed profile to stdout instead of diff")
    args = p.parse_args()
    profile = yaml.safe_load(args.profile.read_text())
    before = dump(profile)
    drop_legacy_file_hashes(profile)
    new = inspect(profile, args.image or profile["tag"])
    if args.emit:
        print(dump(new), end="")
    else:
        diff = list(
            difflib.unified_diff(
                before.splitlines(True),
                dump(new).splitlines(True),
                fromfile=str(args.profile),
                tofile="candidate/profile.yaml",
            )
        )
        sys.stdout.writelines(diff)
        sys.exit(bool(diff))


if __name__ == "__main__":
    main()
