# microk8s cluster node
class sunet::microk8s::node(
  Integer $failure_domain = 42,
) {
  package { 'snapd':
    ensure   =>  latest,
    provider => apt,
  }
  -> exec { 'install_microk8s':
    command => 'snap install microk8s --classic --channel=1.20/stable',
    unless  => 'snap list microk8s',
  }
  -> file { '/etc/docker/daemon.json':
    ensure => file,
    source => template('sunetdrive/node/daemon.json.erb'),
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
}
