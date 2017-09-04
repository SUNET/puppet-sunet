class sunet::rsyslog {
  $syslog_servers = hiera_array('syslog_servers',[])

  package {'rsyslog':
    ensure => 'installed'
  }

  file { '/etc/rsyslog.d/60-remote.conf':
    ensure  => file,
    mode    => '644',
    content => template('sunet/rsyslog/rsyslog-remote.conf.erb'),
    require => Package['rsyslog'],
  }

  service { 'rsyslog':
    ensure    => 'running',
    enable    => true,
    subscribe => File['/etc/rsyslog.d/60-remote.conf'],
  }
}
