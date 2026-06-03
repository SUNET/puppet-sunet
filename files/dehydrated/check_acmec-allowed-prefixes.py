#!/usr/bin/env python3
import yaml
import sys
import socket
import re
import os
import json
from ipaddress import ip_network, ip_address
import argparse

def parse_acmec_non_clients(yaml_path):
    result = []
    all_domains = []

    with open(yaml_path, "r") as f:
        data = yaml.safe_load(f)

    dehydrated = data.get("dehydrated", {})
    # Parse global clients
    other_clients = data.get("dehydrated", {}).get("clients", [])

    for item in other_clients:
        result.append(item)

    for item in dehydrated.get("domains", []):
        if not isinstance(item, dict):
            continue

        for domain, props in item.items():
            all_domains.append(domain)
            if not isinstance(props, dict):
                continue

            # skip anything with clients
            if "clients" in props:
                continue

            names = props.get("names")
            if isinstance(names, list):
                result.extend(names)

    # normalize + dedupe
    return list(dict.fromkeys(h.strip().lower() for h in result if h and h.strip())), list(dict.fromkeys(h.strip().lower() for h in all_domains if h and h.strip()))

def remove_unused_checks(all_domains):
    exclusions = ["gather_inventory", "dehydrated", "update_and_upgrade", "cleanup", "check_infra_cert", "cosmos"]

    files = os.listdir("/etc/scriptherder/check/")

    for f in files:
        if not f.endswith(".ini"):
            continue
        
        fname = f[:-4].replace("dehydrated_", "")
        filepath = f"/etc/scriptherder/check/{f}"
        
        if fname not in all_domains and fname not in exclusions:
            print(f"Removing {filepath}")
            os.remove(filepath)

def resolve_host(hostname):
    ips = set()
    try:
        for res in socket.getaddrinfo(hostname, None):
            ips.add(res[4][0])
    except socket.gaierror:
        pass
    return ips

def load_prefixes(path):
    prefixes = []

    with open(path) as f:
        content = f.read()

    blocks = re.findall(r'\{[^}]+\}', content)

    for block in blocks:
        if '"net"' not in block:
            continue

        try:
            cleaned = re.sub(r',\s*}', '}', block)
            cleaned = re.sub(r',\s*\]', ']', cleaned)

            obj = json.loads(cleaned)

            net = obj.get("net")
            tags = obj.get("tags", [])

            if net:
                prefixes.append({"net": ip_network(net, strict=False), "tags": tags})

        except Exception as e:
            print(f"Failed parsing block: {block}")
            print(e)

    return prefixes

def dedupe_list(items):
    return list(set(items))

def check_hostnames(prefixes, hostnames, required_tag):
    not_resolvable = []
    missing_sunet_prefix = []
    missing_acmec_tag = []

    for hostname in hostnames:
        hostname = hostname.lower()

        ips = resolve_host(hostname)

        if not ips:
            not_resolvable.append(hostname)
            continue

        for ip in ips:
            ip_obj = ip_address(ip)

            matches = [
                p for p in prefixes
                if p["net"].version == ip_obj.version and ip_obj in p["net"]
            ]

            if not matches:
                missing_sunet_prefix.append((hostname, ip))
                continue

            # normalize tags
            required = required_tag.strip().lower()

            # check if ANY matching prefix has the tag
            has_tag = any(
                required in {t.strip().lower() for t in p.get("tags", [])}
                for p in matches
            )

            if not has_tag:
                missing_acmec_tag.append((hostname, ip))

    return not_resolvable, missing_sunet_prefix, missing_acmec_tag

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Check hosts against ip prefixes")
    parser.add_argument("--tag", required=True, help="Tag must exist"
    )

    args = parser.parse_args()
    required_tag = args.tag

    prefixes = load_prefixes("/etc/puppet/cosmos-modules/sunet/lib/puppet/functions/sunet_prefixes.rb")

    acmec_non_clients, all_acmec_domains = parse_acmec_non_clients("/etc/hiera/data/local.yaml")
    remove_unused_checks(all_acmec_domains)

    all_hosts = list(dict.fromkeys(acmec_non_clients))

    results = check_hostnames(prefixes, all_hosts, required_tag)

    not_resolvable, missing_sunet_prefix, missing_acmec_tag = results

    if not_resolvable and missing_sunet_prefix and missing_acmec_tag:
        print('OK')
        sys.exit(0)
    
    print("\n\nNot resolvable:")
    if not not_resolvable:
        print(None)
    else:
        for h in dedupe_list(not_resolvable):
            print(h)

    print("\nMissing from SUNET prefixes:")
    if not missing_sunet_prefix:
        print(None)
    else:
        for h, ip in dedupe_list(missing_sunet_prefix):
            print(f"{h} -> {ip}")

    print("\nMissing acmec tag:")
    if not missing_acmec_tag:
        print(None)
    else:
        for h, ip in dedupe_list(missing_acmec_tag):
            print(f"{h} -> {ip}")

    # Exit codes
    if missing_sunet_prefix or missing_acmec_tag:
        sys.exit(1)  # critical
    elif not_resolvable:
        sys.exit(2) # warning

    sys.exit(0)