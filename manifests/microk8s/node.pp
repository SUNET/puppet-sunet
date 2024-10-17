# microk8s cluster node
class sunet::microk8s::node(
  String  $channel                = '1.28/stable',
  Boolean $traefik                = false,
  Integer $failure_domain         = 42,
  Integer $web_nodeport           = 30080,
  Integer $websecure_nodeport     = 30443,
  Optional[Array[String]] $peers  = [],
) {
  include sunet::packages::snapd

  $hiera_peers =  lookup('microk8s_peers', undef, undef, [])
  if $facts['microk8s_role'] == 'worker' {
    $type = 'worker'
  } else {
    $type = 'controller'
  }

  if $peers != [] {
    $final_peers = $peers
  } elsif $hiera_peers != [] {
    $final_peers = $hiera_peers
  }
  elsif $facts['configured_hosts_in_cosmos']['sunet::microk8s::node'] != [] {
    $final_peers = $facts['configured_hosts_in_cosmos']['sunet::microk8s::node']
  } else {
    warning('Unable to figure out our peers, leaving BROKEN firewalls')
  }
  notice('microk8s peers: ',$final_peers)
  $public_controller_ports = [8080, 8443, 16443]
  $private_controller_ports = [10250, 10255, 25000, 12379, 10257, 10259, 19001]
  $private_worker_ports = [10250, 10255, 16443, 25000, 12379, 10257, 10259, 19001]
  # Loop through peers and do things that require their ip:s
  $final_peers.each | String $peer| {
    $peer_ip = dns_lookup($peer)
    unless $peer == 'unknown' or $facts['networking']['ip'] in $peer_ip {
      $peer_ip.each | String $ip | {
        file_line { "hosts_${peer}_${ip}":
          path => '/etc/hosts',
          line => "${ip} ${peer}",
        }
      }
    }
    if $::facts['sunet_nftables_enabled'] == 'yes' {
      if $type == 'controller' {
        sunet::nftables::allow { "nft_${peer}_private":
          port => $private_controller_ports,
          from => $peer_ip,
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
        sunet::misc::ufw_allow { "nft_${peer}_private":
          port => $private_controller_ports,
          from => $peer_ip,
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
    if $type == 'controller' {
      sunet::nftables::allow { 'nft_public':
        port => $public_controller_ports,
        from => 'any',
      }
    }
  }
  else {
    if $type == 'controller' {
      sunet::misc::ufw_allow { 'nft_public':
        port => $public_controller_ports,
        from => 'any',
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
  -> file { '/etc/docker':
    ensure  => directory,
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
