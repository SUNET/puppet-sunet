# Set ip IPv6 neighbour discovery proxying  (e.g. for a Docker container)
define sunet::misc::ipv6_ndp_proxy(
  String $address,
  String $interface = 'eth0',
) {
  augeas { 'ipv6_ndp_proxy_config':
    context => '/files/etc/sysctl.d/99-ipv6-ndp-proxy.conf',
    changes => [
                'set net.ipv6.conf.eth0.proxy_ndp 1',
                'set net.ipv6.conf.eth0.accept_ra 2',
                ],
    notify  => Exec['reload_sysctl_99-ipv6-ndp-proxy.conf'],
  }

  exec { 'reload_sysctl_99-ipv6-ndp-proxy.conf':
    command     => '/sbin/sysctl -p /etc/sysctl.d/99-ipv6-ndp-proxy.conf',
    # always do this to work around these sysctls not being set :( refreshonly => true,
  }

  exec { "ipv6_ndp_proxy_${address}":
    command => "/sbin/ip -6 neigh add proxy ${address} dev ${interface}",
  }
}
