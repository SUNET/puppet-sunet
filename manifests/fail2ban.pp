class sunet::fail2ban {

  package {'fail2ban':
      ensure => 'latest'
  }
  -> service {'fail2ban':
    ensure => 'running'
  }
  file {'/etc/fail2ban/jail.d/sshd.conf':
    content => template('sunet/fail2ban/jail.sshd.erb'),
    notify  => Exec['reload fail2ban'],
  }
  exec {'reload fail2ban':
    command     => 'systemctl reload fail2ban',
    refreshonly => true,
  }
}
