#!/usr/bin/env python3
# pylint:disable=invalid-name
# pylint:enable=invalid-name
"""
This is a script the checks the health of django-ca and exits with NRPE exit codes based on results.
"""

import subprocess
import sys


def run_django_ca_check() -> str:
    """Run the django-ca check command and return its output"""
    try:
        result = subprocess.run(
            ["django-ca", "check"], capture_output=True, text=True, check=True
        )
        return result.stdout.strip()
    except subprocess.CalledProcessError as e:
        # Return stderr or stdout if available
        return (e.stderr or e.stdout or "Unknown error").strip()


def check_service_active(service_name: str) -> bool:
    """Check if the systemd service is active"""
    try:
        result = subprocess.run(
            ["systemctl", "is-active", service_name],
            capture_output=True,
            text=True,
            check=True,
        )
        return result.stdout.strip() == "active"
    except subprocess.CalledProcessError:
        return False


def main() -> None:
    """The starting point of the program"""

    # Check if the service is running, else exit
    service_name = "sunet-django-ca.service"
    if not check_service_active(service_name):
        print(f"CRITICAL: Service '{service_name}' is not running.")
        sys.exit(2)

    # Check that we dont get any errors running "django-ca check"
    check_output = run_django_ca_check()
    expected_check_output = "System check identified no issues (0 silenced)."
    if check_output == expected_check_output:
        print(f"OK: {check_output}")
        sys.exit(0)
    else:
        print(f"WARNING: Unexpected output:\n{check_output}")
        sys.exit(1)


if __name__ == "__main__":
    main()
