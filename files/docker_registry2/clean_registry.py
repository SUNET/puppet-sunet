#!/usr/bin/env python3

import sys
import subprocess
import ipaddress
import yaml
import registry

# Nagios plugin exit status codes
STATUS = {'OK': 0,
          'WARNING': 1,
          'CRITICAL': 2,
          'UNKNOWN': 3,
         }

def get_container_ip(container_name):
    process = subprocess.Popen([
        '/usr/bin/docker', 'inspect',
        '--format={{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}',
        container_name], stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=False)
    returncode = process.wait()

    if returncode != 0:
        print("Could not get IP address of the registry container")
        sys.exit(STATUS['CRITICAL'])

    # Read the output and remove \n
    container_ip = process.stdout.read().rstrip()

    # Convert the bytes into a string
    container_ip = container_ip.decode("UTF-8")

    try:
        container_ip = ipaddress.ip_address(container_ip)
    except ValueError:
        print("Did not get a properly formatted IP address for the registry container")
        sys.exit(STATUS['CRITICAL'])

    return str(container_ip)

def clean(config):

    if config['registry_url']:
        registry_url = config['registry_url']
    else:
        registry_url = "http://{}:{}".format(get_container_ip(config['registry_container_name']),
                                             config['registry_container_port'])

    for image_to_clean in config['exact_images']:
        print("Starting cleanup of image: {}".format(image_to_clean))
        image_config = config["exact_images"][image_to_clean]
        registry.main_loop(registry.parse_args([
            "--delete", "--order-by-date", "--host", registry_url,
            "--image", image_to_clean,
            "--keep-tags-like", image_config["regex_of_tags_to_save"],
            "--tags-like", image_config["regex_of_tags_to_delete"] or '.',
            "--num", str(image_config["number_of_latest_builds_to_save"])]))

    for group in config['group_images']:
        print("Starting cleanup of group: {}".format(group))
        group_config = config["group_images"][group]
        registry.main_loop(registry.parse_args([
            "--delete", "--order-by-date", "--host", registry_url,
            "--images-like", group,
            "--keep-tags-like", group_config["regex_of_tags_to_save"],
            "--tags-like", group_config["regex_of_tags_to_delete"] or '.',
            "--num", str(group_config["number_of_latest_builds_to_save"])]))

def parse_config(config_file):
    with open(config_file, 'r') as conf_file:
        config = yaml.safe_load(conf_file)

    return config

def main():

    if len(sys.argv) != 2:
        print('Usage: clean_registry.py config_file.yaml')
        sys.exit(STATUS['WARNING'])

    config_file = sys.argv[1]

    # Remove arguments since otherwise they are read by
    # clean_old_versions.py that doesn't recognize our arguments.
    sys.argv = [sys.argv[0]]

    config = parse_config(config_file)
    clean(config)
    sys.exit(STATUS['OK'])

if __name__ == "__main__":
    main()
