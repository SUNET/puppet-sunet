# Disable bridge nf
define sunet::snippets::disable_bridge_nf() {
  augeas { 'server_bridge_nf_config':
    context => '/files/etc/sysctl.d/10-bridge-nf.conf',
    changes => [
                'set net.bridge.bridge-nf-call-arptables 0',
                'set net.bridge.bridge-nf-call-ip6tables 0',
                'set net.bridge.bridge-nf-call-iptables 0'
                ],
    notify  => Exec['reload_sysctl_10_bridge_nf_conf'],
  }

  exec { 'reload_sysctl_10_bridge_nf_conf':
    command     => '/sbin/sysctl -p /etc/sysctl.d/10-bridge-nf.conf',
    refreshonly => true,
  }
}
