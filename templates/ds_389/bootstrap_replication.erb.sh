#!/bin/bash

domain="$(hostname -d)"
fqdn="$(hostname -f)"
dir_manager_password="<%= @dir_manager_password %>"
repl_manager_password="<%= @repl_manager_password %>"
declare -a sites
if [[ ${fqdn} == *sto1v2* ]]; then
  home_base="sto1v2"
  replica_id=1
fi
if [[ ${fqdn} == *sto3* ]]; then
  home_base="sto3"
  replica_id=2
  sites=("sto1v2" "sto4")
fi
if [[ ${fqdn} == *sto4* ]]; then
  home_base="sto4"
  replica_id=3
  sites=("sto1v2" "sto3")
fi

if [[ -z ${replica_id} ]]; then
  echo "You are operating from an unknow datacenter, please teach me about it."
  exit 1
fi

dsconf -D "cn=Directory Manager" -w "${dir_manager_password}" ldap://localhost:3389 backend create --suffix="dc=sunet,dc=dev" --be-name="sunet"
dsconf -D "cn=Directory Manager" ldap://localhost:3389 replication enable --suffix="dc=sunet,dc=dev" \
  --role="supplier" --replica-id="${replica_id}" --bind-dn="cn=replication manager,cn=config" --bind-passwd="${repl_manager_password}"

for site in "${sites[@]}"; do
  dsconf -D "cn=Directory Manager" ldap://localhost:3389 repl-agmt create --suffix="dc=sunet,dc=dev" \
    --host="internal-${site}-test-ldap-1.${domain}" --port=3636 --conn-protocol=LDAPS \
    --bind-dn="cn=replication manager,cn=config" --bind-passwd="${repl_manager_password}" \
    --bind-method=SIMPLE --init "${home_base}-to-${site}"
done
