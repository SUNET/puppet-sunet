import yaml
import os

# Remove acmec checks and cached check data for domains not existing in local.yaml
def remove_unused_checks(all_acmec_domains):
    exclusions = ["gather_inventory", "dehydrated", "update_and_upgrade", "cleanup", "check_infra_cert", "cosmos"]
    files = os.listdir("/etc/scriptherder/check/")
    cfiles = os.listdir("/var/cache/scriptherder")

    for f in files:
        if not f.endswith(".ini"):
            continue
        
        fname = f[:-4].replace("dehydrated_", "").strip().lower()
        filepath = f"/etc/scriptherder/check/{f}"
        
        if fname not in all_acmec_domains and fname not in exclusions:
            os.remove(filepath)

            # Build the cache prefix from the .ini filename
            cfname = f[:-4].replace(".", "_")
            
            # Find and remove all cache files for this specific check
            for cfile in cfiles:
                if cfile.startswith(cfname + "__"):
                    cfilepath = f"/var/cache/scriptherder/{cfile}"
                    os.remove(cfilepath)

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
 remove_unused_checks(all_acmec_domains)