#!/usr/bin/env python3

import os
import yaml
import re
import sys
import socket


def iteritems(d):
    return iter(d.items())


def _all_hosts():
    return list(
        filter(
            lambda fn: "." in fn
            and not fn.startswith(".")
            and os.path.isdir("/var/cache/cosmos/repo/" + fn),
            os.listdir("/var/cache/cosmos/repo"),
        )
    )


rules = dict()
rules_file = "/etc/puppet/cosmos-rules.yaml"
if os.path.exists(rules_file):
    with open(rules_file) as fd:
        rules.update(yaml.load(fd, Loader=yaml.FullLoader))

all_hosts = _all_hosts()

me = socket.gethostbyaddr(socket.gethostname())[0]
for node_name in all_hosts:
    for reg, cls in iteritems(rules):
        if re.match(reg, node_name):
            if node_name == me:
                if cls:
                    for c, p in cls.items():
                        if re.match("sunet::server$", c):
                            if p:
                                if "unattended_upgrades_use_template" in p:
                                    if p["unattended_upgrades_use_template"]:
                                        print("unattended_upgrades_use_template=yes")
                                        sys.exit()

print("unattended_upgrades_use_template=no")
