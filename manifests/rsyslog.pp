class sunet::rsyslog(
  $syslog_servers = hiera_array('syslog_servers',[]),
  $relp_syslog_servers = hiera_array('relp_syslog_servers',[]),
  $udp_port = hiera('udp_port',undef),
  $tcp_port = hiera('tcp_port',undef),
) {
  ensure_resource('package', 'rsyslog', {
    ensure => 'installed'
  })

  file { '/etc/rsyslog.d/60-remote.conf':
    ensure  => file,
    mode    => '644',
    content => template('sunet/rsyslog/rsyslog-remote.conf.erb'),
    require => Package['rsyslog'],
  }

  ensure_resource('service', 'rsyslog', {
    ensure    => 'running',
    enable    => true,
    subscribe => File['/etc/rsyslog.d/60-remote.conf'],
  })

  if $relp_syslog_servers != [] {
    ensure_resource('package', 'rsyslog-relp', {
      ensure => 'installed'
      })
  }

  $set_udp = $udp_port ? {
     undef   => [],
     default => ["set \$ModLoad imudp","set \$UDPServerRun $udp_port"]
  }

  $set_tcp = $tcp_port ? {
     undef   => [],
     default => ["set \$ModLoad imtcp","set \$TCPServerRun $tcp_port"]
  }

  if ($tcp_port or $udp_port) {
     $changes = flatten($set_udp,$set_tcp)
     include augeas
     augeas { "rsyslog_conf":
        context => "/files/etc/rsyslog.conf",
        changes => $changes,
        notify  => Service['rsyslog']
     }
  }

}
