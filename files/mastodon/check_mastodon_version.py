#!/usr/bin/env python3

import os
import sys
import time

import requests
import yaml

API_URL = "https://api.github.com/repos/mastodon/mastodon/releases"
LOCK_FILE = "/tmp/check-mastodon-release.lock"
COMPOSE_FILE = "/opt/mastodon_web/docker-compose.yml"
# 12 hours
DELAY = 43200

try:
    stat = os.stat(LOCK_FILE)
except FileNotFoundError:
    # Lock will be created later on
    stat = None

if stat and stat.st_mtime + DELAY > time.time():
    with open(LOCK_FILE, "r") as file:
        latest_version = file.read()
else:
    try:
        resp = requests.get(url=API_URL)
    except:
        print("WARNING: api.github.com did not responed correctly")
        sys.exit(1)

    try:
        data = resp.json()
    except:
        print("WARNING: api.github.com did not responed with valid JSON")
        sys.exit(1)

    latest_version = data[0]["name"]
    with open(LOCK_FILE, "w") as file:
        file.write(latest_version)

with open(COMPOSE_FILE) as fd:
    data = yaml.safe_load(fd)
    running_version = data["services"]["web"]["image"].split(":")[1]

if latest_version == running_version:
    status = "OK"
    NOT = " "
    exit_value = 0
else:
    NOT = " NOT "
    status = "CRITICAL"
    exit_value = 2


print(f"{status}: We are{NOT}running the latest version ({latest_version}) of Mastodon")
sys.exit(exit_value)
