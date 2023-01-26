# microk8s cluster node
class sunet::microk8s::node(
  String  $channel        = '1.25/stable',
  Boolean $mayastor       = true,
  Integer $failure_domain = 42,
) {
  # Loop through peers and do things that require their ip:s
  include stdlib
  split($facts['microk8s_peers'], ',').each | String $peer| {
    unless $peer == 'unknown' {
      $peer_ip = $facts[join(['microk8s_peer_', $peer])]
      file_line { "hosts_${peer}":
        path => '/etc/hosts',
        line => "${peer_ip} ${peer}",
      }
      -> exec { "ufw_${peer}":
        command => "ufw allow in from ${peer_ip}",
        unless  => "ufw status | grep -Eq 'Anywhere.*ALLOW.*${peer_ip}'" ,
      }
    }
  }
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
  unless any2bool($facts['microk8s_rbac']) {
    exec { 'enable_plugin_rbac':
      command  => '/snap/bin/microk8s enable rbac',
      provider => 'shell',
    }
  }
  unless any2bool($facts['microk8s_dns']) {
    exec { 'enable_plugin_dns':
      command  => '/snap/bin/microk8s enable dns:89.32.32.32',
      provider => 'shell',
    }
  }
  unless any2bool($facts['microk8s_community']) {
    exec { 'enable_community_repo':
      command  => '/snap/bin/microk8s enable community',
      provider => 'shell',
    }
  }
  unless any2bool($facts['microk8s_traefik']) {
    exec { 'enable_plugin_traefik':
      command  => '/snap/bin/microk8s enable traefik',
      provider => 'shell',
    }
  }
  if $enable_mayastor {
    file { '/etc/sysctl.d/20-microk8s-hugepages.conf':
      ensure  => file,
      content => "vm.nr_hugepages = 1024\n",
      mode    => '0644',
    }
    unless any2bool($facts['microk8s_mayastor']) {
      exec { 'enable_plugin_mayastor':
        command  => '/snap/bin/microk8s enable mayastor',
        provider => 'shell',
      }
    }
  }
  $namespaces = hiera_hash('microk8s_secrets', {})
  $namespaces.each |String $namespace, Hash $secrets| {
      $secrets.each |String $name, Array $secret| {
        set_microk8s_secret($namespace, $name, $secret)
    }
  }
  import_gpg_keys_to_microk8s()
}
