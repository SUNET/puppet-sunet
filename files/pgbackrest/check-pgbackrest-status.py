#!/usr/bin/env python3
# pylint:disable=invalid-name
"""Check status of pgBackRest backups: age and stanza health."""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
from datetime import datetime, timedelta, UTC
from typing import List, Tuple, Any, Optional

# NRPE exit codes
OK = 0
WARNING = 1
CRITICAL = 2
UNKNOWN = 3

DEFAULT_STANZA = "patroni"
DEFAULT_TIMEOUT = 30
DEFAULT_MAX_AGE_HOURS = 25


def run_cmd(cmd: List[str], timeout: int) -> Tuple[int, str, str, bool]:
    """
    Execute a shell command with an enforced timeout.

    Args:
        cmd: List of command arguments.
        timeout: Timeout in seconds.

    Returns:
        A tuple of (exit_code, stdout, stderr, timed_out_flag).
    """
    try:
        proc = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=timeout,
            check=False,  # Explicit for pylint W1510
        )
        return proc.returncode, proc.stdout.strip(), proc.stderr.strip(), False

    except subprocess.TimeoutExpired as exc:
        out = exc.stdout.strip() if exc.stdout else ""
        err = exc.stderr.strip() if exc.stderr else ""
        return CRITICAL, out, err, True

    except (OSError, ValueError) as exc:
        # Narrowed exception list to satisfy pylint W0718
        return UNKNOWN, "", str(exc), False


def truncate_one_line(text: str, limit: int = 400) -> str:
    """
    Collapse whitespace and truncate text to a single NRPE-safe line.
    """
    collapsed = " ".join(text.split())
    return collapsed if len(collapsed) <= limit else collapsed[:limit] + "..."


def fmt_utc(dt: datetime) -> str:
    """Format a datetime in compact UTC ISO form with Z suffix."""
    return dt.astimezone(UTC).isoformat(timespec="seconds").replace("+00:00", "Z")


def format_age(delta: timedelta) -> str:
    """Return a human-friendly age string like '3h 12m 9s'."""
    total = int(delta.total_seconds())
    if total < 0:
        return "0s"

    days, rem = divmod(total, 86400)
    hours, rem = divmod(rem, 3600)
    minutes, secs = divmod(rem, 60)

    parts = []
    if days:
        parts.append(f"{days}d")
    if hours or days:
        parts.append(f"{hours}h")
    if minutes or hours or days:
        parts.append(f"{minutes}m")
    parts.append(f"{secs}s")

    return " ".join(parts)


def pick_last_backup_stop_for_stanza(
    info_json: Any, stanza: str
) -> tuple[datetime, Optional[str]]:
    """
    Select the last backup block for the specified stanza from pgBackRest JSON.

    Args:
        info_json: Parsed JSON list from pgbackrest.
        stanza: Stanza name to filter on.

    Returns:
        (stop_time_utc, backup_label)
    """
    if not isinstance(info_json, list):
        raise ValueError("JSON root must be a list of stanza objects.")

    stanza_obj = next(
        (obj for obj in info_json if isinstance(obj, dict) and obj.get("name") == stanza),
        None,
    )
    if stanza_obj is None:
        raise ValueError(f"Stanza '{stanza}' not found.")

    backups = stanza_obj.get("backup")
    if not isinstance(backups, list) or not backups:
        raise ValueError(f"Stanza '{stanza}' has no backup entries.")

    last = backups[-1]
    ts = last.get("timestamp")
    if not isinstance(ts, dict) or not isinstance(ts.get("stop"), int):
        raise ValueError("Invalid or missing timestamp.stop in backup entry.")

    stop_epoch = ts["stop"]
    return datetime.fromtimestamp(stop_epoch, tz=UTC), last.get("label")


def build_args() -> argparse.Namespace:
    """
    Create CLI argument parser for this script.
    """
    parser = argparse.ArgumentParser(
        description="NRPE check for pgBackRest",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument("--stanza", default=DEFAULT_STANZA)
    parser.add_argument("--timeout", type=int, default=DEFAULT_TIMEOUT)
    parser.add_argument("--timeout-info", type=int, default=None)
    parser.add_argument("--timeout-check", type=int, default=None)
    parser.add_argument("--max-age-hours", type=float, default=DEFAULT_MAX_AGE_HOURS)
    parser.add_argument(
        "--debug",
        action="store_true",
        help="Append backup label for debugging",
    )
    return parser.parse_args()


def main() -> None:
    """
    Main entry point for NRPE check logic.
    """
    args = build_args()

    if shutil.which("pgbackrest") is None:
        print("CRITICAL: pgbackrest command not found")
        sys.exit(CRITICAL)

    stanza = args.stanza
    info_timeout = args.timeout_info or args.timeout
    check_timeout = args.timeout_check or args.timeout
    max_age = timedelta(hours=args.max_age_hours)

    # ---- Run pgbackrest info (JSON only) ----
    info_cmd = ["pgbackrest", f"--stanza={stanza}", "info", "--output=json"]
    code, stdout, stderr, timed_out = run_cmd(info_cmd, info_timeout)

    if timed_out:
        print(f"CRITICAL: timeout in 'pgbackrest info' after {info_timeout}s")
        sys.exit(CRITICAL)

    if code != 0:
        print(
            f"CRITICAL: 'pgbackrest info' failed (exit {code}): "
            f"{truncate_one_line(stderr or stdout)}"
        )
        sys.exit(CRITICAL)

    try:
        info_json = json.loads(stdout)
    except (json.JSONDecodeError, TypeError) as exc:
        print(f"CRITICAL: invalid JSON from pgbackrest: {exc}")
        sys.exit(CRITICAL)

    try:
        last_stop_utc, label = pick_last_backup_stop_for_stanza(info_json, stanza)
    except (KeyError, ValueError) as exc:
        print(f"CRITICAL: could not determine last backup: {exc}")
        sys.exit(CRITICAL)

    age = datetime.now(UTC) - last_stop_utc
    if age > max_age:
        msg = (
            f"CRITICAL: last backup too old — "
            f"stop={fmt_utc(last_stop_utc)} age={format_age(age)} "
            f"(max {args.max_age_hours}h)"
        )
        if args.debug and label:
            msg += f" label={label}"
        print(msg)
        sys.exit(CRITICAL)

    # ---- Run pgbackrest check ----
    check_cmd = ["pgbackrest", f"--stanza={stanza}", "check"]
    code, stdout2, stderr2, timed_out = run_cmd(check_cmd, check_timeout)

    if timed_out:
        print(f"CRITICAL: timeout in 'pgbackrest check' after {check_timeout}s")
        sys.exit(CRITICAL)

    if code != 0:
        print(
            f"CRITICAL: 'pgbackrest check' failed (exit {code}): "
            f"{truncate_one_line(stderr2 or stdout2)}"
        )
        sys.exit(CRITICAL)

    msg = (
        "OK: pgBackRest healthy — "
        f"Last backup={fmt_utc(last_stop_utc)} age={format_age(age)}"
    )
    if args.debug and label:
        msg += f" label={label}"
    print(msg)
    sys.exit(OK)


if __name__ == "__main__":
    main()
