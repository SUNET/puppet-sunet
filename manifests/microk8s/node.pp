# microk8s cluster node
class sunet::microk8s::node(
  Integer $failure_domain = 42,
) {
  package { 'snapd':
    ensure   =>  latest,
    provider => apt,
  }
  -> exec {'install_microk8s':
    command => 'snap install microk8s --classic',
    unless  => 'snap list microk8s',
  }
  -> file_line {'microk8s_ha_conf':
    line => "failure-domain=${failure_domain}",
    path => '/var/snap/microk8s/current/args/ha-conf'
  }
}
