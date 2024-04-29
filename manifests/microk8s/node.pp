# microk8s cluster node
class sunet::microk8s::node(
  String  $channel            = '1.27/stable',
  Boolean $mayastor           = false,
  Boolean $traefik            = true,
  Integer $failure_domain     = 42,
  Integer $web_nodeport       = 30080,
  Integer $websecure_nodeport = 30443,
) {
  # Loop through peers and do things that require their ip:s
  include sunet::packages::snapd

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
  exec { 'install_microk8s':
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
    port => [8080, 8443, 16443, 10250, 10255, 25000, 12379, 10257, 10259, 19001, 30443],
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
    $line1 ="/snap/bin/microk8s enable traefik --set ports.websecure.nodePort=${websecure_nodeport}"
    $line2 = "--set  ports.web.nodePort=${web_nodeport} --set deployment.kind=DaemonSet"
    $traefik_command = "${line1} ${line2}"
    unless any2bool($facts['microk8s_traefik']) and $traefik {
      exec { 'enable_plugin_traefik':
        command  => $traefik_command,
        provider => 'shell',
      }
    }
  }
  exec { 'alias_kubectl':
    command  => '/usr/bin/snap alias microk8s.kubectl kubectl',
    provider => 'shell',
  }
  exec { 'alias_helm':
    command  => '/usr/bin/snap alias microk8s.helm helm',
    provider => 'shell',
  }
  if $mayastor {
    package { "linux-modules-extra-${facts['kernelrelease']}":
      ensure   =>  installed,
      provider => apt,
    }
    file {'/etc/modules-load.d/microk8s-mayastor.conf':
      ensure  => file,
      content => "nvme_tcp\n",
      mode    => '0644',
    }
    file { '/etc/sysctl.d/20-microk8s-hugepages.conf':
      ensure  => file,
      content => "vm.nr_hugepages = 4096\n",
      mode    => '0644',
    }
    unless any2bool($facts['microk8s_mayastor']) {
      exec { 'enable_plugin_mayastor':
        command  => '/snap/bin/microk8s enable mayastor',
        provider => 'shell',
      }
    }
  }
  $namespaces = lookup('microk8s_secrets', undef, undef, {})
  $namespaces.each |String $namespace, Hash $secrets| {
      $secrets.each |String $name, Array $secret| {
        set_microk8s_secret($namespace, $name, $secret)
    }
  }
  #import_gpg_keys_to_microk8s()
}
