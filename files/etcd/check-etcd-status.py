#!/usr/bin/env python3
# pylint:disable=invalid-name
# pylint:enable=invalid-name
"""
This is a script the checks the health of etcd and exits with NRPE exit codes based on results.
"""

import subprocess
import sys
from typing import Dict, List


def run_etcdctl_command(args: List[str]) -> str:
    """Run etcdctl command and return raw output, even if it fails"""
    try:
        result = subprocess.run(args, capture_output=True, text=True, check=True)
        return result.stdout
    except subprocess.CalledProcessError as e:
        # print(f"WARNING: etcdctl command failed: {e}")
        return e.stdout or e.stderr or ""


def parse_table_output(output: str) -> List[Dict[str, str]]:
    """Parse etcdctl table output into a list of dictionaries"""

    # Split the raw output into lines
    lines = output.strip().splitlines()

    data = []  # This will hold the parsed rows as dictionaries
    headers: List[str] = []  # This will hold the column headers
    parsing = False  # Flag to indicate when we're inside the table

    for line in lines:
        # The first '+' line marks the start of the table
        if line.startswith("+") and not parsing:
            parsing = True
            continue
        # The first '|' line after '+' contains the headers
        elif line.startswith("|") and not headers:
            headers = [h.strip() for h in line.strip("|").split("|")]
        # Subsequent '|' lines contain row data
        elif line.startswith("|") and headers:
            values = [v.strip() for v in line.strip("|").split("|")]
            row = dict(
                zip(headers, values)
            )  # Combine headers and values into a dictionary
            data.append(row)
        # '+' lines after the table start are just borders, we skip them
        elif line.startswith("+") and parsing:
            continue

    return data  # List of dictionaries, one per row


def safe_parse_table_output(output: str) -> List[Dict[str, str]]:
    """Try to parse table output, return empty list on failure"""
    try:
        return parse_table_output(output)
    except Exception as e:
        print(f"WARNING: Failed to parse output: {e}")
        return []


def print_health_info(health_data: List[Dict[str, str]]) -> None:
    """Print health status for each endpoint"""
    print("\netcd Health Status:")
    for row in health_data:
        endpoint = row.get("ENDPOINT", "unknown")
        health = row.get("HEALTH", "false")
        took = row.get("TOOK", "N/A")
        status = "healthy" if health.lower() == "true" else "unhealthy"
        print(f"{endpoint}: {status} (took {took})")


def print_status_info(status_data: List[Dict[str, str]]) -> None:
    """Print leader info and version for each endpoint"""
    print("\netcd Cluster Status:")
    for row in status_data:
        endpoint = row.get("ENDPOINT", "unknown")
        version = row.get("VERSION", "unknown")
        is_leader = row.get("IS LEADER", "false")
        role = "leader" if is_leader.lower() == "true" else "follower"
        print(f"{endpoint}: {role}, version={version}")


def print_member_info(member_data: List[Dict[str, str]]) -> None:
    """Print member status"""
    print("\netcd Member List:")
    for row in member_data:
        name = row.get("NAME", "unknown")
        status = row.get("STATUS", "unknown")
        print(f"{name}: {status}")


def main() -> None:
    """The starting point of the program"""

    # Run etcdctl commands
    health_output = run_etcdctl_command(
        ["etcdctl", "endpoint", "health", "--cluster", "-w", "table"]
    )
    status_output = run_etcdctl_command(
        ["etcdctl", "endpoint", "status", "--cluster", "-w", "table"]
    )
    member_output = run_etcdctl_command(["etcdctl", "member", "list", "-w", "table"])

    # Convert output to structured data (since we )
    health_data = safe_parse_table_output(health_output)
    status_data = safe_parse_table_output(status_output)
    member_data = safe_parse_table_output(member_output)

    # Sanity check: if health or member data is empty, warn
    if not health_data:
        print(
            "CRITICAL: No health data received. etcdctl health command may have failed."
        )
        sys.exit(2)
    if not member_data:
        print("CRITICAL: No member data received. etcdctl member list may have failed.")
        sys.exit(2)

    # Make sure all enpoints have status health: true
    all_healthy = True
    for row in health_data:
        health = row.get("HEALTH", "false")
        if health.lower() != "true":
            all_healthy = False

    # Make sure all enpoints have status: started
    all_started = True
    for row in member_data:
        status = row.get("STATUS", "unknown")
        if status.lower() != "started":
            all_started = False

    if all_healthy and all_started:
        print("OK: All etcd nodes are healthy and is 'started'")
        # Print health and status info
        print_health_info(health_data)
        print_status_info(status_data)
        print_member_info(member_data)
        sys.exit(0)
    else:
        # Print health and status info
        print("WARNING: Not all etcd nodes are healthy or started")
        print_health_info(health_data)
        print_status_info(status_data)
        print_member_info(member_data)
        sys.exit(1)


if __name__ == "__main__":
    main()
