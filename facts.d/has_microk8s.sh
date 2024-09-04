#!/bin/sh
if [ -e /var/snap/microk8s/current/var/lock/clustered.lock ]; then
  echo 'microk8s_role=worker'
  echo 'microk8s=yes'
elif [ -f /snap/bin/microk8s ]; then
  echo 'microk8s_role=controller'
  echo 'microk8s=yes'
  modules=$(/snap/bin/microk8s status --format short)
  for module in dns ha-cluster openebs traefik; do
    echo ${modules} | grep "^${module}: enabled"  >/dev/null 2>&1
    if [ ${?} -eq 0 ]; then
      echo "microk8s_${module}=yes"
    else
      echo "microk8s_${module}=no"
    fi
  done
  peers="$(/snap/bin/microk8s kubectl get nodes -o json | jq -r '.items[].metadata.name' | grep -v $(hostname -s))"
  if [ "x${peers}" != "x" ]; then
    output="microk8s_peers="
    for peer in $(echo ${peers}); do
        output="${output}${peer},"
    done
    output=$(echo "${output}"| sed 's/,$//')
    echo "${output}"
    /snap/bin/microk8s kubectl get nodes -o json | jq -r '.items[].metadata | "microk8s_peer_\(.name)=\(.annotations."projectcalico.org/IPv4Address")"' | grep -v $(hostname -s) | sed 's_/23__'
  else
    echo 'microk8s_peers=unknown'
  fi
else
  echo 'microk8s=no'
  echo 'microk8s_community=no'
  echo 'microk8s_dns=no'
  echo 'microk8s_ha-cluster=no'
  echo 'microk8s_mayastor=no'
  echo 'microk8s_peers=unknown'
  echo 'microk8s_rbac=no'
  echo 'microk8s_traefik=no'
  echo 'microk8s_role=none'
fi
