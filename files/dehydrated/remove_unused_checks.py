import yaml
import os
import sys

# Remove acmec checks and cached check data for domains not existing in local.yaml
def remove_unused_checks(all_acmec_domains):
    has_errors = False
    
    try:
        checks = os.listdir("/etc/scriptherder/check/")
        cached_checks = os.listdir("/var/cache/scriptherder")
    except OSError as e:
        print(f"Failed to list directories: {e}")
        return True

    for f in checks:
        if not f.startswith("dehydrated_") or not f.endswith(".ini"):
            continue
        
        fn_check = f[:-4].replace("dehydrated_", "").strip().lower()
        fp_check = f"/etc/scriptherder/check/{f}"
        
        if fn_check not in all_acmec_domains:
            # Try to remove the .ini file
            try:
                os.remove(fp_check)
                print(f"Removed unused check: {fp_check}")
            except OSError as e:
                print(f"Failed to remove {fp_check}: {e}")
                has_errors = True
            
            # Build the cache prefix from the .ini filename
            fn_cache = f[:-4].replace(".", "_")
            
            # Find and remove all cache files for this specific check
            for cfile in cached_checks:
                if cfile.startswith(fn_cache + "__"):
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