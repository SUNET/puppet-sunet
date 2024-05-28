# microk8s cluster node
class sunet::microk8s::node(
  String  $channel                = '1.28/stable',
  Boolean $traefik                = true,
  Integer $failure_domain         = 42,
  Integer $web_nodeport           = 30080,
  Integer $websecure_nodeport     = 30443,
  Optional[Array[String]] $peers  = [],
) {
  include sunet::packages::snapd

  $hiera_peers =  lookup('microk8s_peers', undef, undef, [])
  if $facts['hostname'] =~ /(^kubew|k8sw-)[0-9]/ {
    $type = 'worker'
  } else {
    $type = 'controller'
  }

  if $peers != [] {
    $final_peers = $peers
  } elsif $hiera_peers != [] {
    $final_peers = $hiera_peers
  } else {
    $final_peers = map(split($facts['microk8s_peers'], ',')) | String $peer| {
      $peer_ip = $facts[join(['microk8s_peer_', $peer])]
      "${peer_ip} ${peer}"
    }
  }
    # Loop through peers and do things that require their ip:s
  $final_peers.each | String $peer_tuple| {
    $peer_ip = split($peer_tuple, ' ')[0]
    $peer = split($peer_tuple, ' ')[1]
    unless $peer == 'unknown' or $peer_ip == $facts['ipaddress'] {
      file_line { "hosts_${peer}":
        path => '/etc/hosts',
        line => "${peer_ip} ${peer}",
      }
    }
    $public_controller_ports = [8080, 8443, 16443]
    $private_controller_ports = [10250, 10255, 25000, 12379, 10257, 10259, 19001]
    $private_worker_ports = [10250, 10255, 16443, 25000, 12379, 10257, 10259, 19001]
    if $::facts['sunet_nftables_enabled'] == 'yes' {
      if $type == 'controller' {
        sunet::nftables::allow { "nft_${peer}_private":
          port => $private_controller_ports,
          from => $peer_ip,
        }
        sunet::nftables::allow { "nft_${peer}_public":
          port => $public_controller_ports,
          from => 'any',
        }
      } else {
        sunet::nftables::allow { "nft_${peer}_private":
          port => $private_worker_ports,
          from => $peer_ip,
        }
      }
      sunet::nftables::allow { "nft_${peer}_udp":
        port  => [4789],
        from  => $peer_ip,
        proto => 'udp',
      }
    } else {
      if $type == 'controller' {
        sunet::misc::ufw_allow {"nft_${peer}_private":
          port => $private_controller_ports,
          from => $peer_ip,
        }
        sunet::misc::ufw_allow { "nft_${peer}_public":
          port => $public_controller_ports,
          from => 'any',
        }
      } else {
        sunet::misc::ufw_allow { "nft_${peer}_private":
          port => $private_worker_ports,
          from => $peer_ip,
        }
      }
      sunet::misc::ufw_allow { "nft_${peer}_udp":
        port  => [4789],
        from  => $peer_ip,
        proto => 'udp',
      }
    }
  }
  if $::facts['sunet_nftables_enabled'] == 'yes' {
    file { '/etc/nftables/conf.d/500-microk8s-rules.nft':
      ensure  => file,
      content => template('sunet/microk8s/500-microk8s-rules.nft.erb'),
      mode    => '0644',
    }
  } else {
    # This is how ufw::allow does it, but that lacks support for "on"
    exec { 'allow-outgoing-on-calico':
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
  $namespaces = lookup('microk8s_secrets', undef, undef, {})
  $namespaces.each |String $namespace, Hash $secrets| {
      $secrets.each |String $name, Array $secret| {
        set_microk8s_secret($namespace, $name, $secret)
    }
  }
}
