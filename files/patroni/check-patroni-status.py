#!/usr/bin/env python3
# pylint:disable=invalid-name
# pylint:enable=invalid-name
"""
This is a script the checks the health of patroni and exits with NRPE exit codes based on result.
"""

import json
import sys
from typing import Dict, Any

import requests


def print_status_info(
    patroni_status: Dict[str, Any], patroni_cluster_info: Dict[str, Any]
) -> None:
    """Print status metadata for patroni"""
    role = patroni_status.get("role")
    server_version = patroni_status.get("server_version")
    patroni_version = patroni_status.get("patroni", {}).get("version")

    print(f"Role: {role}")
    print(f"Postgres Version: {server_version}")
    print(f"Patroni Version: {patroni_version}")

    if role == "primary":
        replication_peers = patroni_status.get("replication", [])
        print("Replication Peers:")
        for peer in replication_peers:
            app_name = peer.get("application_name")
            state = peer.get("state")
            print(f"- {app_name}: state={state}")

    elif role == "replica":
        for member in patroni_cluster_info.get("members", []):
            if member.get("role") == "leader":
                leader = member.get("name")
                print(f"Current Leader: {leader}")


def main() -> None:
    """The starting point of the program"""

    # Paths
    patroni_status_url = "http://localhost:8008/patroni"
    patroni_cluster_url = "http://localhost:8008/cluster"

    try:

        # Get the info from the /patroni endpoint
        response = requests.get(patroni_status_url, timeout=10)
        response.raise_for_status()
        patroni_status = response.json()

        # Get the info from the /cluster endpoint
        response = requests.get(patroni_cluster_url, timeout=10)
        response.raise_for_status()
        patroni_cluster_info = response.json()

        # Get the state so we know how to exit
        state = patroni_status.get("state")

        if state == "running":
            print(f"OK: Patroni is running as expected, state is: '{state}'")
            print_status_info(patroni_status, patroni_cluster_info)
            sys.exit(0)
        else:
            print(f"CRITICAL: Patroni is not running as expected, state is: '{state}'")
            print_status_info(patroni_status, patroni_cluster_info)
            sys.exit(2)

    except requests.exceptions.Timeout:
        print(f"WARNING: Request to '{patroni_status_url}' timed out.")
        sys.exit(1)
    except requests.exceptions.ConnectionError:
        print(f"WARNING: Failed to connect to '{patroni_status_url}'")
        sys.exit(1)
    except requests.exceptions.HTTPError as e:
        print(f"WARNING: HTTP error occurred: {e}")
        sys.exit(1)
    except json.JSONDecodeError:
        print(f"WARNING: Failed to decode JSON from '{patroni_status_url}'")
        sys.exit(1)
    except Exception as e:
        print(f"UNKNOWN: Error occurred: {e}")
        sys.exit(3)


if __name__ == "__main__":
    main()
