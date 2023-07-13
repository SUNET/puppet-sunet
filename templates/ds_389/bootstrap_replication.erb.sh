#!/bin/bash

domain="$(hostname -d)"
fqdn="$(hostname -f)"
dir_manager_password="<%= @dir_manager_password %>"
repl_manager_password="<%= @repl_manager_password %>"
replica_id=1
if [[ ${fqdn} == *sto1v2* ]]; then
  replica_id=2
fi
if [[ ${fqdn} == *sto3* ]]; then
  replica_id=3
fi

dsconf -D "cn=Directory Manager" -w "${dir_manager_password}" ldap://localhost:3389 backend create --suffix="dc=sunet,dc=dev" --be-name="sunet"
dsconf -D "cn=Directory Manager" ldap://localhost:3389 replication enable --suffix="dc=sunet,dc=dev" \
  --role="supplier" --replica-id="${replica_id}" --bind-dn="cn=replication manager,cn=config" --bind-passwd="${repl_manager_password}"

if [[ ${fqdn} == *sto1v2* ]]; then
  index=2
  for site in sto1v2 sto3; do
    dsconf -D "cn=Directory Manager" ldap://localhost:3389 repl-agmt create --suffix="dc=sunet,dc=dev" \
      --host="internal-${site}-test-ldap-1.${domain}" --port=3636 --conn-protocol=LDAPS \
      --bind-dn="cn=replication manager,cn=config" --bind-passwd="${repl_manager_password}" \
      --bind-method=SIMPLE --init "supplier1-to-supplier${index}"
    index=$((index +1))
  done
fi
