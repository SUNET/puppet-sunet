import yaml
import os
import sys

# Remove acmec checks and cached check data for domains not existing in local.yaml
def remove_unused_checks(all_acmec_domains):
    has_errors = False
    exclusions = ["gather_inventory", "dehydrated", "update_and_upgrade", "cleanup", "check_infra_cert", "cosmos"]
    
    try:
        files = os.listdir("/etc/scriptherder/check/")
        cfiles = os.listdir("/var/cache/scriptherder")
    except OSError as e:
        print(f"Failed to list directories: {e}")
        return True

    for f in files:
        if not f.endswith(".ini"):
            continue
        
        fname = f[:-4].replace("dehydrated_", "").strip().lower()
        filepath = f"/etc/scriptherder/check/{f}"
        
        if fname not in all_acmec_domains and fname not in exclusions:
            # Try to remove the .ini file
            try:
                os.remove(filepath)
                print(f"Removed unused check: {filepath}")
            except OSError as e:
                print(f"Failed to remove {filepath}: {e}")
                has_errors = True
            
            # Build the cache prefix from the .ini filename
            cfname = f[:-4].replace(".", "_")
            
            # Find and remove all cache files for this specific check
            for cfile in cfiles:
                if cfile.startswith(cfname + "__"):
                    cfilepath = f"/var/cache/scriptherder/{cfile}"
                    try:
                        os.remove(cfilepath)
                        print(f"Removed unused check caches: {cfilepath}")
                    except OSError as e:
                        print(f"Failed to remove {cfilepath}: {e}")
                        has_errors = True

    return has_errors


def parse_acmec_domains(yaml_path):
    all_domains = []

    with open(yaml_path, "r") as f:
        data = yaml.safe_load(f)

    dehydrated = data.get("dehydrated", {})

    for item in dehydrated.get("domains", []):
        if not isinstance(item, dict):
            continue

        for domain, props in item.items():
            all_domains.append(domain)

    # Normalize and deduplicate
    return list(dict.fromkeys(h.strip().lower() for h in all_domains if h and h.strip()))

if __name__ == "__main__":
    all_acmec_domains = parse_acmec_domains("/etc/hiera/data/local.yaml")
    
    if remove_unused_checks(all_acmec_domains):
        sys.exit(2)
    else:
        sys.exit(0)