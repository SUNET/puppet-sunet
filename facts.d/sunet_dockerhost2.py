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
                    for c in cls:
                        if re.match("(.+)::dockerhost2$",c):
                            print("dockerhost2=yes")
                            sys.exit()

print("dockerhost2=no")
