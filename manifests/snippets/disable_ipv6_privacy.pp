# Disable IPv6 privacy extensions on servers. Complicates troubleshooting.
define sunet::snippets::disable_ipv6_privacy() {
  augeas { 'server_ipv6_privacy_config':
    context => '/files/etc/sysctl.d/10-ipv6-privacy.conf',
    changes => [
                'set net.ipv6.conf.all.use_tempaddr 0',
                'set net.ipv6.conf.default.use_tempaddr 0',
                ],
    notify  => Exec['reload_sysctl_10-ipv6-privacy.conf'],
  }

  exec { 'reload_sysctl_10-ipv6-privacy.conf':
    command     => '/sbin/sysctl -p /etc/sysctl.d/10-ipv6-privacy.conf',
    refreshonly => true,
  }
}
