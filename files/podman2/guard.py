#!/usr/bin/python3
"""Enforce a podman2 release receipt through systemd's service hooks.

Before startup, check the host files, image tag and effective service against
the receipt written by converge.py. After startup, inspect the process and
its mounts in the rootless user namespace. A failure marker blocks subsequent
starts until the unit is recovered.
"""

import errno
import hashlib
import json
import os
import re
import shlex
import stat
import struct
import subprocess
import sys
from pathlib import Path

BASE = Path("/var/lib/sunet-podman2")
BOOT = Path("/run/sunet-podman2-ready")


def require(ok, reason):
    """Raise ValueError with the failed check's diagnostic if the condition is false."""
    if not ok:
        raise ValueError(reason)


def digest(path):
    """Return a file's hexadecimal SHA-256 digest."""
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def executable_mount(mount):
    """Recognize current and legacy executable mounts by their host release directory."""
    return Path(mount["source"]).is_relative_to(BASE / "releases")


def check_executable(path):
    """Require a regular, root-owned, mode 0555 file at the bind source itself."""
    # lstat also rejects a symlink to an otherwise acceptable executable.
    st = path.lstat()
    require(
        stat.S_ISREG(st.st_mode) and st.st_uid == 0 and stat.S_IMODE(st.st_mode) == 0o555,
        f"expected a root-owned, mode 0555 executable at {path}",
    )


# Root writes this attribute on the replacement inode before publishing it.
IMAGE_ATTR = "user.sunet_podman2.image"


def executable_image(path):
    """Read the image ID recorded on this inode, or return None if the attribute is absent."""
    try:
        return os.getxattr(path, IMAGE_ATTR, follow_symlinks=False).decode()
    except OSError as exc:
        if exc.errno == errno.ENODATA:
            return None
        raise


def label(path):
    """Return the SELinux type and complete MLS/MCS range from the file context."""
    return os.getxattr(path, "security.selinux").rstrip(b"\0").decode().split(":", 2)[2]


def policy_generation():
    """Read the kernel's policy-load counter for comparison with the boot marker."""
    # The selinuxfs status page contains version, sequence, enforcing, policyload.
    with open("/sys/fs/selinux/status", "rb") as status:
        return str(struct.unpack("=4I", status.read(16))[3])


def generated_hash(contents):
    """Hash the effective service while normalizing Quadlet's unordered options.

    The dry run and systemd's generator can emit independent options in
    different orders. Repeated values for a key and the application's
    argument order must still compare exactly.
    """
    lines = [line for line in contents.splitlines() if line and not line.startswith("#")]
    tag = next(line[6:] for line in lines if line.startswith("Image="))
    for i, line in enumerate(lines):
        if not line.startswith("ExecStart=/usr/bin/podman run "):
            continue
        args = shlex.split(line)
        end = args.index(tag)
        # Quadlet iterates Go maps when emitting these independent options.
        # Preserve argument order after the image and repeated assignments to the same key.
        fixed = []
        options = {}
        j = 0
        while j < end:
            arg = args[j]
            if arg in ("--env", "--pull", "--shm-size", "--network-alias"):
                value = args[j + 1]
                key = arg + (":" + value.partition("=")[0] if arg == "--env" else "")
                options.setdefault(key, []).append(value)
                j += 2
            else:
                fixed.append(arg)
                j += 1
        lines[i] = json.dumps([fixed, options, args[end:]], sort_keys=True)
    return hashlib.sha256("\n".join(lines).encode()).hexdigest()


def check(name, release, live=False):
    """Verify a unit against the expected state in its active release receipt.

    Run the host ownership and image-attribute checks as barnbarn. The live
    pass runs inside Podman's user namespace so it can inspect mapped files
    through the running process's root directory.
    """
    require(Path("/sys/fs/selinux/enforce").read_text().strip() == "1", "SELinux must enforce")
    require(BOOT.exists(), "boot policy check pending")
    require(not (BASE / "operator-holds" / name).exists(), f"{name} is on operator hold")
    require(not (BASE / "holds" / name / "failed").exists(), f"{name} is on operator hold")
    if "generated" in release:
        require(BOOT.read_text() == policy_generation(), "loaded policy needs host verification")
        contents = subprocess.check_output(["systemctl", "--user", "cat", name + ".service"], text=True)
        require(
            generated_hash(contents) == release["generated"], "effective service differs from reviewed unit"
        )
    current = subprocess.check_output(
        ["podman", "image", "inspect", "--format", "{{.Id}}", release["tag"]], text=True
    ).strip()
    require(current == release["image"], "active tag differs from qualified build")
    for mount in release["mounts"]:
        src = Path(mount["source"])
        require(label(src) == mount["label"], f"incorrect SELinux context on {src}")
        if executable_mount(mount) and not live:
            check_executable(src)
            # Legacy layouts predate the image-ID attribute. With a stable
            # source path, the inode records which build supplied its bytes.
            if release.get("stable_executables"):
                require(executable_image(src) == release["image"], f"wrong executable image at {src}")
    if not live:
        return
    raw = subprocess.check_output(["podman", "container", "inspect", name])
    obj = json.loads(raw)[0]
    proc = Path("/proc") / str(obj["State"]["Pid"])
    expected = release["domain"] + ":" + release["level"]
    require(
        obj["State"]["Running"] and obj["Image"].removeprefix("sha256:") == current.removeprefix("sha256:"),
        "wrong live image",
    )
    require(
        (proc / "attr/current").read_text().strip("\0\n").split(":", 2)[2] == expected,
        "wrong live domain/MCS",
    )
    require(obj["HostConfig"]["ReadonlyRootfs"], "writable root")
    mounts = {m["Destination"]: m for m in obj["Mounts"]}
    for mount in release["mounts"]:
        actual = mounts[mount["target"]]
        require(actual["Source"] == mount["source"] and actual["RW"] == mount["rw"], "incorrect mount")
        source = Path(mount["source"])
        dest = proc / "root" / mount["target"].lstrip("/")
        # Podman can report the expected source path even if the bind mount
        # still pins an inode replaced during an update.
        require(source.samefile(dest), f"bind mount inode differs at {mount['target']}")


def main():
    """Dispatch the start, post-start and stop hooks and latch service failures."""
    mode, name = sys.argv[1:]
    require(re.fullmatch("[a-z][a-z0-9-]*", name), "invalid unit name")
    latch = BASE / "holds" / name / "failed"
    if mode == "stopped":
        # A planned recreation or host shutdown must allow the next start.
        controlled = (Path("/run/sunet-podman2-switch") / name).exists()
        shutdown = (
            subprocess.run(["systemctl", "is-system-running"], capture_output=True, text=True).stdout.strip()
            == "stopping"
        )
        if not controlled and not shutdown and os.environ.get("SERVICE_RESULT") not in (None, "success"):
            latch.touch()
        return
    release = json.loads((BASE / "active" / (name + ".json")).read_text())
    try:
        if mode == "live":
            check(name, release)
            # The new namespace can stat bind mounts belonging to mapped payload UIDs.
            subprocess.run(["podman", "unshare", sys.executable, __file__, "_live", name], check=True)
        else:
            check(name, release, live=mode == "_live")
    except Exception:
        latch.touch()
        raise


if __name__ == "__main__":
    main()
