
define sunet::frontend::load_balancer::sysctl_ip_nonlocal_bind() {
  # Allow haproxy to bind() to a service IP address even if it haven't actually
  # been set up on an interface yet
  augeas { 'frontend_ip_nonlocal_bind_config':
    context => '/files/etc/sysctl.d/10-sunet-frontend-ip-non-local-bind.conf',
    changes => [
                'set net.ipv4.ip_nonlocal_bind 1',
                'set net.ipv6.ip_nonlocal_bind 1',
                ],
    notify  => Exec['reload_sysctl_10-sunet-frontend-ip-non-local-bind.conf'],
  }

  exec { 'reload_sysctl_10-sunet-frontend-ip-non-local-bind.conf':
    command     => '/sbin/sysctl -p /etc/sysctl.d/10-sunet-frontend-ip-non-local-bind.conf',
    refreshonly => true,
  }
}
