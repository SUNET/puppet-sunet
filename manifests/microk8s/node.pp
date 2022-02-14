# microk8s cluster node
class sunet::microk8s::node(
  String  $channel        = '1.21/stable',
  Boolean $enable_openebs = true,
  Integer $failure_domain = 42,
) {

  package { 'snapd':
    ensure   =>  latest,
    provider => apt,
  }
  -> exec { 'install_microk8s':
    command => "snap install microk8s --classic --channel=${channel}",
    unless  => 'snap list microk8s',
  }
  -> file { '/etc/docker/daemon.json':
    ensure  => file,
    content => template('sunet/microk8s/daemon.json.erb'),
    mode    => '0644',
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
    command  => 'ufw allow out on vxlan.calico',
    path     => '/usr/sbin:/bin:/usr/bin',
    unless   => 'ufw status | grep -qE "ALLOW OUT   Anywhere (\(v6\) |)on vxlan.calico"',
    provider => 'posix',
  }
  -> exec { 'allow-incomming-on-calico':
    command  => 'ufw allow in on vxlan.calico',
    path     => '/usr/sbin:/bin:/usr/bin',
    unless   => 'ufw status | grep -qE "Anywhere (\(v6\) |)on vxlan.calico"',
    provider => 'posix',
  }
  -> exec { 'iptables-allow-forward':
    command  => 'iptables -P FORWARD ACCEPT',
    path     => '/usr/sbin:/bin:/usr/bin',
    provider => 'shell',
    unless   => 'iptables -L FORWARD | grep -q "Chain FORWARD (policy ACCEPT)"',
  }

  -> split($facts['microk8s_peers'], ',').each | String $peer| {
    file_line { "hosts_${peer}":
      path => '/etc/hosts',
      line => "${facts[join(['microk8s_peer_', $peer])]} ${peer}",
    }
    -> exec { "ufw_${peer}":
      command => "ufw allow in from ${facts[join(['microk8s_peer_', $peer])]}",
      unless  => "ufw status | grep -Eq 'Anywhere.*ALLOW.*${facts[join(['microk8s_peer_', $peer])]}'" ,
    }
  }
  -> unless any2bool(facts['microk8s_dns']) {
    exec { 'enable_plugin_dns':
      command  => '/snap/bin/microk8s enable dns:89.32.32.32',
      provider => 'shell',
    }
  }
  -> unless any2bool(facts['microk8s_traefik']) {
    exec { 'enable_plugin_traefik':
      command  => '/snap/bin/microk8s enable traefik',
      provider => 'shell',
    }
  }
  -> if $enable_openebs {
    service { 'iscsid_enabled_running':
      ensure   => running,
      enable   => true,
      name     => 'iscsid.service',
      provider => systemd,
    }
    -> unless any2bool(facts['microk8s_openebs']) {
      exec { 'enable_plugin_openebs':
        command  => '/snap/bin/microk8s enable openebs',
        provider => 'shell',
      }
    }
  }
}
