#!/usr/bin/env python3

import os
import yaml
import re
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

bankids = []
me = socket.gethostbyaddr(socket.gethostname())[0]
my_instance = ""
for node_name in all_hosts:
    for reg, cls in iteritems(rules):
        if re.match(reg, node_name):
            if "sunet::bankidp" in cls:
                instance = cls["sunet::bankidp"]["instance"]
                if node_name == me:
                    my_instance = instance
                    # Don't include itself in the host lists. Not sure if this is a good idea or not. Time will tell.
                    continue
                app = False
                redis = False
                if "app_node" in cls["sunet::bankidp"]:
                    app = True
                if "redis_node" in cls["sunet::bankidp"]:
                    redis = True

                node = {
                    "node_name": node_name,
                    "app": app,
                    "redis": redis,
                    "instance": instance,
                }

                bankids.append(node)

apps = []
redises = []

for host in bankids:
    if my_instance == host["instance"]:
        if host["app"]:
            apps.append(host["node_name"])
        if host["redis"]:
            redises.append(host["node_name"])

output = {
    "bankid_cluster_info": {
        "instance": my_instance,
        "apps": apps,
        "redises": redises,
    }
}

print(yaml.dump(output, default_flow_style=None))
