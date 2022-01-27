# microk8s cluster node
class sunet::microk8s::node(
  Integer $failure_domain = 42,
) {
  package { 'snapd':
    ensure   =>  latest,
    provider => apt,
  }
  -> exec {'install_microk8s':
    command => 'snap install microk8s --classic --channel=1.20/stable',
    unless  => 'snap list microk8s',
  }
  -> file_line {'microk8s_ha_conf':
    line => "failure-domain=${failure_domain}",
    path => '/var/snap/microk8s/current/args/ha-conf'
  }
  -> sunet::misc::ufw_allow { 'microk8s_ports':
    from => '0.0.0.0/0',
    port => [8080, 8443, 16443, 10250, 10255, 25000, 12379, 10257, 10259, 19001],
  }
}
