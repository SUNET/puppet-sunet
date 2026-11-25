# Fail2ban module
class sunet::fail2ban {
  if $facts['os']['name'] == 'AlmaLinux' {
    ensure_packages(['epel-release'])
    # The EPEL metapackage selects firewalld. SUNET manages nftables directly.
    $package = 'fail2ban-server'
    Package['epel-release'] -> Package[$package]
    # Start the simple service with its jail already on disk. A reload
    # immediately after starting can race the creation of its control socket.
    $on_change = Service['fail2ban']
  } else {
    $package = 'fail2ban'
    $on_change = Exec['reload fail2ban']
    exec { 'reload fail2ban':
      command     => 'systemctl reload fail2ban',
      refreshonly => true,
      require     => Service['fail2ban'],
    }
  }
  package { $package:
    ensure => latest,
  }
  service { 'fail2ban':
    ensure  => running,
    enable  => true,
    require => Package[$package],
  }
  file { '/etc/fail2ban/jail.d/sshd.conf':
    require => Package[$package],
    content => template('sunet/fail2ban/jail.sshd.erb'),
    notify  => $on_change,
  }
}
