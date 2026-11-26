#!/usr/bin/python3
"""Puppet convergence for the dedicated barnbarn Podman store."""

import collections
import fcntl
import graphlib
import hashlib
import json
import os
import pwd
import re
import subprocess
import sys
import tempfile
from pathlib import Path

import guard
from guard import BASE, require

SCRIPTS = Path(__file__).resolve().parent
ACCOUNT = "barnbarn"
UID = pwd.getpwnam(ACCOUNT).pw_uid
UNITS = Path(f"/etc/containers/systemd/users/{UID}")
RT = f"/run/user/{UID}"
ACTIVE = BASE / "active"
DATA = BASE / "data"
IDENT = r"[a-z][a-z0-9_]*"
NAME = r"[a-z][a-z0-9-]*"
SAFE_PATH = r"/(?:[A-Za-z0-9_.-]+/)*[A-Za-z0-9_.-]+"


def run(*argv, **kwargs):
    return subprocess.run(list(map(str, argv)), check=True, **kwargs)


def as_user(*args):
    return [
        "runuser",
        "-u",
        ACCOUNT,
        "--",
        "env",
        f"HOME=/home/{ACCOUNT}",
        f"XDG_RUNTIME_DIR={RT}",
        f"DBUS_SESSION_BUS_ADDRESS=unix:path={RT}/bus",
        *args,
    ]


def out(*args):
    return run(*args, stdout=subprocess.PIPE, text=True).stdout.strip()


def save(path, data, mode=0o644):
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists() and path.read_bytes() == data.encode():
        return
    with tempfile.NamedTemporaryFile(dir=path.parent, delete=False) as f:
        tmp = Path(f.name)
        try:
            f.write(data.encode())
            f.flush()
            os.fchmod(f.fileno(), mode)
            os.fsync(f.fileno())
            os.replace(tmp, path)
        finally:
            tmp.unlink(missing_ok=True)


def encoded(obj):
    return json.dumps(obj, sort_keys=True, separators=(",", ":"))


def context(path, typ, level, apply, tree=False):
    expected = typ + ":" + level
    expr = re.escape(str(path)) + ("(/.*)?" if tree else "")
    current = out("matchpathcon", "-n", path).split(":", 2)[2]
    if current != expected:
        require(apply, f"persistent file context needs reconciliation: {path}")
        # -a refuses a conflicting existing local entry. A migration needs review.
        run("semanage", "fcontext", "-a", "-t", typ, "-r", level, expr)
    if apply and guard.label(path) != expected:
        run("restorecon", "-F", path)
    require(guard.label(path) == expected, f"incorrect context on {path}")


def valid_path(path):
    return re.fullmatch(SAFE_PATH, path) and not {".", ".."}.intersection(path.split("/"))


def validate(record):
    p = record["profile"]
    name = record["name"]
    require(
        re.fullmatch(NAME, name) and re.fullmatch(IDENT, p["module"]) and re.fullmatch(IDENT, p["domain"]),
        "invalid catalog identifier",
    )
    require(
        re.fullmatch(r"[a-z0-9.-]+(?::[0-9]+)?/[a-z0-9._/-]+:[a-zA-Z0-9_.-]+", p["tag"]),
        "use a fully-qualified, tagged registry image",
    )
    require(p["platform"] == "linux/amd64", "unsupported pilot platform")
    level = record["level"]
    require(re.fullmatch(r"s0:c\d+,c\d+", level), "invalid process categories")
    cats = [int(c[1:]) for c in level[3:].split(",")]
    require(0 <= cats[0] < cats[1] <= 1023, "invalid process categories")
    require(set(record["bindings"]) == set(p["datasets"]), f"{name}: incomplete dataset bindings")
    targets = []
    for key, ds in p["datasets"].items():
        bind = record["bindings"][key]
        src = bind["path"]
        require(
            valid_path(src) and Path(src).is_relative_to(DATA) and Path(src) != DATA, "invalid dataset root"
        )
        require(
            ds["access"] in ("rw", "ro")
            and ds["kind"] in ("dir", "file")
            and re.fullmatch(IDENT, ds["type"]),
            "invalid dataset specification",
        )
        require(
            bind["level"] == level or bind["level"] in {"s0:c" + str(c) for c in cats},
            "invalid dataset categories",
        )
        targets.append(ds["target"])
    entries = p["executables"]
    approved = {e["target"] for e in entries}
    require(
        entries and any(e["access"] in ("runtime", "both") for e in entries), "missing runtime entrypoint"
    )
    for e in entries:
        require(
            re.fullmatch(IDENT, e["type"])
            and re.fullmatch("[0-9a-f]{64}", e["sha256"])
            and e["access"] in ("runtime", "child", "both")
            and valid_path(e["path"]),
            "invalid executable",
        )
        require(not e.get("interpreter") or e["interpreter"][0] in approved, "missing shebang interpreter")
        require(all(v == e["target"] for v in e.get("alias_targets", {}).values()), "alias target mismatch")
        targets.append(e["target"])
    require(
        all(valid_path(t) for t in targets) and len(set(targets)) == len(targets),
        "invalid or duplicate target",
    )
    for t in targets:
        require(not any(str(a) in targets for a in Path(t).parents), "nested mounts shadow reviewed paths")
    # Only these application settings can be supplied. Security, execution and
    # lifecycle directives are composed here. Reject continuations and systemd escapes.
    allowed = {
        "Network",
        "NetworkAlias",
        "PublishPort",
        "Environment",
        "Secret",
        "Tmpfs",
        "User",
        "Exec",
        "HealthCmd",
        "HealthInterval",
        "HealthRetries",
        "HealthStartPeriod",
        "ShmSize",
        "DNS",
    }
    section = None
    execution = {}
    for line in record["quadlet"].splitlines():
        if not line or line.startswith("#"):
            continue
        if line == "[Container]" and section is None:
            section = "Container"
            continue
        k, sep, v = line.partition("=")
        require(
            section and sep and k in allowed and v and not any(c in v for c in "\r\\%\x00"),
            f"{name}: unapproved Quadlet directive {k}",
        )
        if k in ("Exec", "User", "HealthCmd"):
            require(k not in execution, f"{name}: duplicate {k}")
            execution[k] = v
        if k == "Secret":
            for opt in v.split(",")[1:]:
                if opt.startswith("target="):
                    require(
                        re.fullmatch(r"target=[A-Za-z0-9_.-]+", opt) and opt.split("=")[1] not in (".", ".."),
                        "secret target must be a name under /run/secrets or an environment key",
                    )
        if k == "Tmpfs":
            dest = v.split(":")[0]
            require(
                dest in ("/tmp", "/run/postgresql") and "noexec" in v.split(":")[-1].split(","),
                "unapproved tmpfs",
            )
    require(section, "missing [Container]")
    require(
        execution == p["unit_contract"], f"{name}: startup, identity or health command differs from profile"
    )


def install_policy(records, apply, check_dependencies=True):
    modules = {r["profile"]["module"]: r for r in records}
    domains = {}
    installed = out("semodule", "-lfull", "-m").splitlines()
    for r in records:
        p = r["profile"]
        require(
            domains.setdefault(p["domain"], p)["executables"] == p["executables"],
            "conflicting grants for one domain",
        )
        require(modules[p["module"]]["cil"] == r["cil"], "conflicting image module revisions")
        if check_dependencies:
            for dep in set(p["dependencies"]) - modules.keys():
                require(re.fullmatch(IDENT, dep), "invalid policy dependency")
                owned = BASE / "policy" / (dep + ".cil")
                require(owned.is_file(), "missing provider module " + dep)
                expected = ["400", dep, "cil", "sha256:" + guard.digest(owned)]
                require(
                    [line.split() for line in installed if line.split()[1] == dep] == [expected],
                    "retained provider module differs: " + dep,
                )
    changed = []
    for mod, r in modules.items():
        data = r["cil"]
        h = hashlib.sha256(data.encode()).hexdigest()
        rows = [line.split() for line in installed if line.split()[1] == mod]
        if rows and all(row[0:3] == ["400", mod, "cil"] and row[3] == "sha256:" + h for row in rows):
            continue
        if not apply:
            raise ValueError("policy update pending")
        require(
            not rows or all(row[0] == "400" for row in rows) and (BASE / "policy" / (mod + ".cil")).exists(),
            "SELinux module name already owned",
        )
        path = BASE / "policy" / (mod + ".cil")
        save(path, data)
        changed.append(path)
    if changed:
        run("semodule", "-X", "400", "-i", *changed)
    # The cache key covers the live kernel policy and every requested grant.
    expected = {domain: p["executables"] for domain, p in domains.items()}
    cache_key = hashlib.sha256(
        (guard.digest(Path("/sys/fs/selinux/policy")) + encoded(expected)).encode()
    ).hexdigest()
    cache = BASE / "verified-policy"
    if cache.exists() and cache.read_text() == cache_key:
        return
    from setools import SELinuxPolicy, TERuleQuery

    policy = SELinuxPolicy("/sys/fs/selinux/policy")
    for p in domains.values():
        policy.lookup_type(p["domain"])
        for cls, perm, permitted in (
            ("file", "entrypoint", ["runtime", "both"]),
            ("file", "execute_no_trans", ["child", "both"]),
            ("process", "transition", []),
            ("process", "dyntransition", []),
        ):
            rules = TERuleQuery(policy, source=p["domain"], tclass=[cls], ruletype=["allow"], perms=[perm])
            actual = {str(t) for rule in rules.results() for t in rule.target.expand()}
            require(
                actual == {e["type"] for e in p["executables"] if e["access"] in permitted},
                f"{p['domain']}: effective {perm} differs from profile",
            )

    save(cache, cache_key)


def qualify(group):
    p = group[0]["profile"]
    tag = p["tag"]
    ident = out(*as_user("python3", SCRIPTS / "image.py", "_stage", tag, p["platform"]))
    require(re.fullmatch(r"(sha256:)?[0-9a-f]{64}", ident), "invalid candidate identity")
    for r in group:
        prof = r["profile"]
        # stdin/stdout boundary: the image store is never accessed as root.
        checked = run(
            *as_user(
                "python3",
                "-c",
                "import json,sys;sys.path.insert(0,sys.argv[1]);import image;"
                "print(json.dumps(image.inspect(json.load(sys.stdin),sys.argv[2])))",
                SCRIPTS,
                ident,
            ),
            input=encoded(prof),
            text=True,
            stdout=subprocess.PIPE,
        )
        require(
            json.loads(checked.stdout) == prof,
            f"{tag}: changed executable or startup contract; review {r['source']}",
        )
    return ident


def host_id(value, mapping):
    for inside, outside, length in mapping:
        if inside <= value < inside + length:
            return outside + value - inside
    raise ValueError("payload ID outside rootless map")


def data_mount(r, key, ds, maps, apply):
    b = r["bindings"][key]
    path = Path(b["path"])
    # Ancestors of a root-managed binding must be administrator-owned directories.
    for parent in reversed(path.parents):
        if not parent.is_relative_to(DATA):
            continue
        if apply:
            parent.mkdir(exist_ok=True, mode=0o755)
        st = parent.lstat()
        require(
            parent.is_dir() and not parent.is_symlink() and st.st_uid == 0 and not st.st_mode & 0o022,
            f"unsafe parent {parent}",
        )
    require(not path.is_symlink(), f"refusing symlink {path}")
    created = not path.exists()
    if created:
        require(apply and ds["kind"] == "dir", f"site must provision {path}")
        path.mkdir(mode=0o700)
        os.chown(path, host_id(ds["uid"], maps[0]), host_id(ds["gid"], maps[1]))
    require((path.is_dir() if ds["kind"] == "dir" else path.is_file()), "wrong dataset kind")
    expected = ds["type"] + ":" + b["level"]
    if apply and guard.label(path) != expected:
        # Never import a populated directory implicitly.
        require(
            not path.is_dir() or not any(path.iterdir()),
            f"stopped backed-up label migration required: {path}",
        )
    if b.get("caddyfile"):
        require(ds["access"] == "ro" and ds["kind"] == "dir" and key == "conf", "invalid Caddyfile binding")
        if created:
            os.chown(path, 0, 0)
            path.chmod(0o755)
        require(
            path.stat().st_uid == 0 and not path.stat().st_mode & 0o022,
            "Caddy configuration must be root-owned",
        )
    context(path, ds["type"], b["level"], apply, path.is_dir())
    if b.get("caddyfile"):
        source = Path("/etc/sunet-podman2/Caddyfile")
        dest = path / "Caddyfile"
        if not dest.exists() or guard.digest(source) != guard.digest(dest):
            require(apply, "Caddy reload pending")
            save(dest, source.read_text())
        if apply:
            run("restorecon", "-F", dest)
    return {"source": str(path), "target": ds["target"], "label": expected, "rw": ds["access"] == "rw"}


def prepare(r, ident, apply):
    p = r["profile"]
    mounts = []
    for e in p["executables"]:
        path = BASE / "releases" / p["module"] / e["sha256"] / e["type"]
        if not path.exists() and apply:
            path.parent.mkdir(parents=True, exist_ok=True)
            with tempfile.NamedTemporaryFile(dir=path.parent, delete=False) as f:
                tmp = Path(f.name)
                try:
                    run(
                        *as_user("podman", "unshare", "python3", SCRIPTS / "image.py", "_read", ident),
                        input=encoded({"copy": e["target"]}).encode(),
                        stdout=f,
                    )
                    f.flush()
                    require(guard.digest(tmp) == e["sha256"], "extracted bytes differ from profile")
                    os.fchmod(f.fileno(), 0o555)
                    os.replace(tmp, path)
                finally:
                    tmp.unlink(missing_ok=True)
        require(guard.digest(path) == e["sha256"], "release hash mismatch")
        context(path, e["type"], "s0", apply)
        mounts.append(
            {
                "source": str(path),
                "target": e["target"],
                "label": e["type"] + ":s0",
                "rw": False,
                "sha256": e["sha256"],
            }
        )
    maps = [
        [
            [int(i) for i in line.split()]
            for line in out(*as_user("podman", "unshare", "cat", f"/proc/self/{kind}_map")).splitlines()
        ]
        for kind in ("uid", "gid")
    ]
    mounts.extend(data_mount(r, k, ds, maps, apply) for k, ds in p["datasets"].items())
    return {
        "image": ident,
        "tag": p["tag"],
        "domain": p["domain"],
        "level": r["level"],
        "mounts": mounts,
        "profile": r["source"],
    }


def unit(r, release):
    n = r["name"]
    lines = [
        r["quadlet"].strip(),
        f"ContainerName={n}",
        f"Image={release['tag']}",
        "Pull=never",
        f"SecurityLabelType={release['domain']}",
        f"SecurityLabelLevel={release['level']}",
        "NoNewPrivileges=true",
        "DropCapability=all",
        "ReadOnly=true",
    ]
    if any(line.startswith("HealthCmd=") for line in r["quadlet"].splitlines()):
        lines.append("Notify=healthy")
    for m in release["mounts"]:
        opts = "rw" if m["rw"] else "ro"
        if "sha256" not in m:
            opts += ",nodev,nosuid,noexec"
        lines.append(f"Volume={m['source']}:{m['target']}:{opts}")
    if r.get("after"):
        deps = " ".join(n + ".service" for n in r["after"])
        lines += ["", "[Unit]", "Wants=" + deps, "After=" + deps]
    return "\n".join(
        [
            *lines,
            "",
            "[Service]",
            f"ExecStartPre={SCRIPTS}/guard.py pre {n}",
            f"ExecStartPost={SCRIPTS}/guard.py live {n}",
            f"ExecStopPost={SCRIPTS}/guard.py stopped {n}",
            "TimeoutStartSec=180",
            "MemoryMax=2G",
            "TasksMax=512",
            "Restart=on-failure",
            "RestartSec=10",
            "",
            "[Install]",
            "WantedBy=default.target",
            "",
        ]
    )


def preview(name, contents):
    # Generate from one root-owned source outside all drop-in search paths.
    directory = BASE / "preview" / name
    source = directory / (name + ".container")
    if not source.exists() or source.read_text() != contents:
        save(source, contents)
    result = out(
        *as_user("env", f"QUADLET_UNIT_DIRS={directory}", "/usr/libexec/podman/quadlet", "-user", "-dryrun")
    )
    header, _, body = result.partition("\n")
    require(
        header == f"---{name}.service---" and "ExecStart=/usr/bin/podman run " in body,
        "Quadlet generation failed",
    )
    body = body.replace(f"SourcePath={source}", f"SourcePath={UNITS / source.name}")
    return guard.generated_hash(body)


def ctl(*args):
    return out(*as_user("systemctl", "--user", *args))


def hold(name):
    save(BASE / "operator-holds" / name, "confinement or activation failed\n")
    ctl("stop", name + ".service")
    print(f"ALERT {name} stopped; inspect journal and repair before clearing hold", file=sys.stderr)


def check_live(name):
    run(*as_user(SCRIPTS / "guard.py", "live", name))
    require(ctl("show", name, "-p", "DropInPaths", "--value") == "", "unexpected service drop-in")
    require(
        ctl("show", name, "-p", "SourcePath", "--value") == str(UNITS / (name + ".container")),
        "unexpected unit source",
    )


def reload_caddy(r, apply):
    source = Path("/etc/sunet-podman2/Caddyfile")
    applied = BASE / "reloaded" / r["name"]
    expected = guard.digest(source)
    if not applied.exists() or applied.read_text() != expected:
        require(apply, "Caddy reload pending")
        run(
            *as_user(
                "podman", "exec", r["name"], "/usr/bin/caddy", "reload", "--config", "/etc/caddy/Caddyfile"
            )
        )
        save(applied, expected)


def execute(mode, recoveries=()):
    records = [
        json.loads(line)
        for line in Path("/etc/sunet-podman2/catalog").read_text().splitlines()
        if line.strip()
    ]
    by_name = {r["name"]: r for r in records}
    require(len(by_name) == len(records), "duplicate container name")
    require(
        len({r["level"] for r in records}) == len(records),
        "assign separate process categories to each instance",
    )
    graph = {r["name"]: r.get("after", []) for r in records}
    records = [by_name[n] for n in graphlib.TopologicalSorter(graph).static_order()]
    groups = collections.defaultdict(list)
    names = set()
    bindings = {}
    for r in records:
        validate(r)
        n = r["name"]
        require(n not in names, "duplicate unit")
        names.add(n)
        for k, b in r["bindings"].items():
            ds = r["profile"]["datasets"][k]
            value = (ds["type"], b["level"], ds["kind"], ds["uid"], ds["gid"])
            require(bindings.setdefault(b["path"], value) == value, "inconsistent shared data binding")
        groups[r["profile"]["tag"]].append(r)
    enforcing = Path("/sys/fs/selinux/enforce")
    if not enforcing.exists() or enforcing.read_text().strip() != "1":
        if mode in ("apply", "recover"):
            for path in ACTIVE.glob("*.json"):
                hold(path.stem)
        raise ValueError("enforcing SELinux required")
    apply = mode in ("apply", "recover")
    if apply:
        dropin = Path(f"/etc/systemd/system/user@{UID}.service.d/50-sunet-podman2.conf")
        order = "[Unit]\nWants=sunet-podman2-boot.service\nAfter=sunet-podman2-boot.service\n"
        if not dropin.exists() or dropin.read_text() != order:
            save(dropin, order)
            run("systemctl", "daemon-reload")
    for recovery in recoveries:
        require(
            recovery in names
            and (
                (BASE / "operator-holds" / recovery).exists()
                or (BASE / "holds" / recovery / "failed").exists()
            ),
            "select a managed unit on hold",
        )
        ctl("stop", recovery)
    # Use the last qualified profiles when a new catalog or image is rejected.
    serving = {}
    for path in ACTIVE.glob("*.json"):
        last = json.loads(path.read_text())
        if "contract" in last:
            serving[path.stem] = json.loads((BASE / "contracts" / last["contract"]).read_text())
        elif path.stem in by_name:
            serving[path.stem] = by_name[path.stem]
    if serving:
        try:
            install_policy(list(serving.values()), False, False)
        except Exception:
            if apply:
                for name, record in serving.items():
                    try:
                        install_policy([record], False, False)
                    except Exception:
                        hold(name)
            raise
    if mode == "boot":
        save(guard.BOOT, guard.policy_generation())
        return
    save(guard.BOOT, guard.policy_generation())
    blocked_tags = set()
    rejected = []
    for path in ACTIVE.glob("*.json"):
        name = path.stem
        if name not in names:
            require(apply, "retirement pending")
            ctl("stop", name)
            (UNITS / (name + ".container")).unlink(missing_ok=True)
            path.unlink()
            ctl("daemon-reload")
            continue
        if name in recoveries:
            continue
        # Existing confinement failures take precedence over registry availability.
        try:
            check_live(name)
        except (OSError, ValueError, subprocess.SubprocessError) as exc:
            if apply:
                hold(name)
            blocked_tags.add(by_name[name]["profile"]["tag"])
            rejected.append(f"{name}: {exc}")
    candidates = {}
    for tag, group in groups.items():
        if any(by_name[dep]["profile"]["tag"] in blocked_tags for r in group for dep in r["after"]):
            blocked_tags.add(tag)
            rejected.append(f"{tag}: dependency is on hold")
        if tag in blocked_tags:
            continue
        try:
            candidates[tag] = qualify(group)
        except Exception as exc:
            blocked_tags.add(tag)
            rejected.append(str(exc))
    # A rejected candidate must not change the policy of its serving release.
    policies = [r for r in records if r["profile"]["tag"] in candidates]
    policies.extend(
        r
        for name, r in serving.items()
        if name in names and by_name[name]["profile"]["tag"] not in candidates
    )
    try:
        install_policy(policies, apply)
    except Exception:
        if apply:
            for name, previous in serving.items():
                try:
                    install_policy([previous], False, False)
                except Exception:
                    hold(name)
        raise
    save(guard.BOOT, guard.policy_generation())
    for tag, ident in candidates.items():
        changes = []
        for r in groups[tag]:
            name = r["name"]
            target = UNITS / (name + ".container")
            state = ACTIVE / (name + ".json")
            release = prepare(r, ident, apply)
            contract = encoded({"profile": r["profile"], "cil": r["cil"]})
            release["contract"] = hashlib.sha256(contract.encode()).hexdigest()
            contract_path = BASE / "contracts" / release["contract"]
            if apply and not contract_path.exists():
                save(contract_path, contract)
            contents = unit(r, release)
            release["generated"] = preview(name, contents)
            latch = BASE / "holds" / name
            if name in recoveries:
                (BASE / "operator-holds" / name).unlink(missing_ok=True)
                (latch / "failed").unlink(missing_ok=True)
            require(
                not (BASE / "operator-holds" / name).exists() and not (latch / "failed").exists(),
                f"{name} on operator hold",
            )
            if (
                name not in recoveries
                and state.exists()
                and json.loads(state.read_text()) == release
                and target.read_text() == contents
            ):
                if any(b.get("caddyfile") for b in r["bindings"].values()):
                    reload_caddy(r, apply)
                continue
            require(apply, "release change pending")
            if not state.exists():
                require(
                    not target.exists() and not ctl("show", name, "-p", "FragmentPath", "--value"),
                    f"unit already owned: {name}",
                )
            latch.mkdir(parents=True, exist_ok=True)
            os.chown(latch, UID, -1)
            changes.append((r, release, target, state, contents))
        if changes:
            for r, *_ in changes:
                for dep in r["after"]:
                    require(
                        ctl("is-active", dep) == "active", f"{dep} must be active before starting {r['name']}"
                    )
            try:
                for r, release, target, state, contents in changes:
                    save(target, contents)
                    save(state, encoded(release))
                ctl("daemon-reload")
                for r, release, *_ in changes:
                    n = r["name"]
                    require(
                        guard.generated_hash(ctl("cat", n)) == release["generated"],
                        "effective service differs from isolated generator output",
                    )
                    require(
                        ctl("show", n, "-p", "SourcePath", "--value") == str(UNITS / (n + ".container"))
                        and not ctl("show", n, "-p", "DropInPaths", "--value"),
                        "unexpected generated service",
                    )
                save(guard.BOOT, guard.policy_generation())
                run(*as_user("podman", "tag", ident, tag))
                for r, *_ in changes:
                    switching = Path("/run/sunet-podman2-switch") / r["name"]
                    save(switching, "controlled service recreation")
                    try:
                        ctl("restart", r["name"])
                    finally:
                        switching.unlink(missing_ok=True)
                    check_live(r["name"])
                    if any(b.get("caddyfile") for b in r["bindings"].values()):
                        reload_caddy(r, True)
            except Exception:
                for r, *_ in changes:
                    hold(r["name"])
                raise
    if rejected:
        raise ValueError("; ".join(rejected))


if __name__ == "__main__":
    mode, *names = sys.argv[1:]
    os.chdir("/")
    require(
        (mode in ("apply", "check", "boot") and not names)
        or (mode == "recover" and names and all(re.fullmatch(NAME, n) for n in names)),
        "usage: check | apply | boot | recover UNIT [UNIT ...]",
    )
    with open("/run/sunet-podman2.lock", "a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        try:
            execute(mode, names)
        except Exception as exc:
            sys.exit(f"podman2 {mode}: {exc}")
