# microk8s cluster node
class sunet::microk8s::node(
  Integer       $failure_domain = 42,
) {

  # I admit that this is not the prettiest ever,
  # but we get all info directly from the cluster, and get zero conf
  $hosts_command = ["/snap/bin/microk7s kubectl get nodes -o wide | awk '",
                    '{ print $6 " " $1 }',
                    "' | tail -n +2 | grep -v $(hostname)  >> /etc/hosts"]

  $cluster_fw_command = ['for i in $(/snap/bin/microk8s kubectl get nodes -o wide | ',
                        'awk "{print $1}"| tail -n +2 | grep -v $(hostname)); do ',
                        'for j in $(host ${i}.$(hostname -d) | awk "{print $NF}"); do ',
                        'ufw status | grep -Eq "Anywhere.*ALLOW.*${j}" || ',
                        'ufw allow in from ${j}; done; done;']

  $plugin_condition  = ['[[ 4 -eq $(/snap/bin/microk8s status --format short | ',
                      'grep -E "(dns: enabled|ha-cluster: enabled|openebs: enabled|traefik: enabled)" | wc -l) ]]']

  package { 'snapd':
    ensure   =>  latest,
    provider => apt,
  }
  -> exec { 'install_microk8s':
    command => 'snap install microk8s --classic --channel=1.21/stable',
    unless  => 'snap list microk8s',
  }
  -> service { 'iscsid_enabled_running':
    ensure   => running,
    enable   => true,
    name     => 'iscsid.service',
    provider => systemd,
  }
  -> file { '/etc/docker/daemon.json':
    ensure => file,
    source => template('sunet/microk8s/daemon.json.erb'),
    mode   => '0644',
  }
  -> file { '/var/snap/microk8s/current/args/ha-conf':
    ensure  => file,
    content => "failure-domain=${failure_domain}\n",
    mode    => '0660',
  }
  -> sunet::misc::ufw_allow { 'microk8s_ports':
    from => 'any',
    port => [8080, 8443, 16443, 10250, 10255, 25000, 12379, 10257, 10259, 19001],
  }
  # This is how ufw::allow does it, but that lacks support for "on"
  -> exec { 'allow-outgoing-on-calico':
    path     => '/usr/sbin:/bin:/usr/bin',
    unless   => 'ufw status | grep -qE "Anywhere (\(v6\) |)on vxlan.calico"',
    provider => 'posix',
    command  => 'ufw allow in on vxlan.calico',
  }
  -> exec { 'allow-incomming-on-calico':
    path     => '/usr/sbin:/bin:/usr/bin',
    unless   => 'ufw status | grep -qE "ALLOW OUT   Anywhere (\(v6\) |)on vxlan.calico"',
    provider => 'posix',
    command  => 'ufw allow in on vxlan.calico',
  }
  -> exec { 'iptables-allow-forward':
    path     => '/usr/sbin:/bin:/usr/bin',
    unless   => 'iptables -L FORWARD | grep -q "Chain FORWARD (policy ACCEPT)"',
    provider => 'posix',
    command  => 'iptables -P FORWARD ACCEPT',
  }
  -> exec { 'fix_etc_hosts':
    command => join($hosts_command),
    onlyif  => '[[ 3 -eq $(/snap/bin/microk8s kubectl get nodes | grep Ready | wc -l) ]]',
    unless  => 'grep kube /etc/hosts | grep -vq "127.0"',
  }
  -> exec { 'add_cluster_to_fw':
    command => join($cluster_fw_command),
    if      => '[[ 3 -eq $(/snap/bin/microk8s kubectl get nodes | grep Ready | wc -l) ]]',
  }
  -> exec { 'enable_plugins':
    command => '/snap/bin/microk8s enable dns:89.32.32.32 traefik openebs',
    unless  => join($plugin_condition),
  }
}
