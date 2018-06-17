class sunet::rsyslog(
  $syslog_servers = hiera_array('syslog_servers',[]),
  $relp_syslog_servers = hiera_array('relp_syslog_servers',[]),
  $udp_port = hiera('udp_port',undef),
  $udp_client = hiera('udp_client',"any"),
  $tcp_port = hiera('tcp_port',undef),
  $tcp_client = hiera('tcp_client',"any"),
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

  if ($tcp_port or $udp_port) {
     augeas { "rsyslog_conf_imuxsock":
        changes => ['set /files/etc/rsyslog.conf/\$ModLoad imuxsock'],
        notify  => Service['rsyslog'],
        onlyif  => "match /files/etc/rsyslog.conf/\$ModLoad/imuxsock size == 0"
     }
     augeas { "rsyslog_conf_imklog":
        changes => ['set /files/etc/rsyslog.conf/\$ModLoad imklog'],
        notify  => Service['rsyslog'],
        onlyif  => "match /files/etc/rsyslog.conf/\$ModLoad/imklog size == 0"
     }
     $set_udp = $udp_port ? {
        undef   => [],
        default => ["set /files/etc/rsyslog.conf/\$UDPServerRun $udp_port"]
     }

     $set_tcp = $tcp_port ? {
        undef   => [],
        default => ["set /files/etc/rsyslog.conf/\$TCPServerRun $tcp_port"]
     }

     if ($udp_port) {
        augeas { "rsyslog_conf_imudp":
           changes => ['set /files/etc/rsyslog.conf/\$ModLoad imudp'],
           notify  => Service['rsyslog'],
           onlyif  => "match /files/etc/rsyslog.conf/\$ModLoad/imudp size == 0"
        }
        ufw::allow { "allow-syslog-udp-${udp_port}": 
           from  => "${udp_client}",
           ip    => 'any',
           proto => 'udp',
           port  => "${udp_port}"
        }
     }

     if ($tcp_port) {
        augeas { "rsyslog_conf_imtcp":
           changes => ['set /files/etc/rsyslog.conf/\$ModLoad imtcp'],
           notify  => Service['rsyslog'],
           onlyif  => "match /files/etc/rsyslog.conf/\$ModLoad/imtcp size == 0"
        }
        ufw::allow { "allow-syslog-tcp-${tcp_port}":
           from  => "${tcp_client}",
           ip    => 'any',
           proto => 'tcp',
           port  => "${tcp_port}"
        }
     }

     $changes = flatten([$common,$set_udp,$set_tcp])
     include augeas
     augeas { "rsyslog_conf":
        context => "/files/etc/rsyslog.conf",
        changes => $changes,
        notify  => Service['rsyslog']
     }

  }

}
