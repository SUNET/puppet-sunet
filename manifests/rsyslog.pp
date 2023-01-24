class sunet::rsyslog(
  $syslog_servers = hiera_array('syslog_servers',[]),
  $relp_syslog_servers = hiera_array('relp_syslog_servers',[]),
  $syslog_enable_remote = safe_hiera('syslog_enable_remote','true'),
  $udp_port = hiera('udp_port',undef),
  $udp_client = hiera('udp_client',"any"),
  $tcp_port = hiera('tcp_port',undef),
  $tcp_client = hiera('tcp_client',"any"),
) {
  include stdlib
  ensure_resource('package', 'rsyslog', {
    ensure => 'installed'
  })

  $do_remote = str2bool($syslog_enable_remote)

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

     if ($udp_port) {
        ufw::allow { "allow-syslog-udp-${udp_port}": 
           from  => "${udp_client}",
           ip    => 'any',
           proto => 'udp',
           port  => "${udp_port}"
        }
     }

     if ($tcp_port) {
        ufw::allow { "allow-syslog-tcp-${tcp_port}":
           from  => "${tcp_client}",
           ip    => 'any',
           proto => 'tcp',
           port  => "${tcp_port}"
        }
     }

     file { '/etc/rsyslog.d/50-local.conf':
       ensure  => file,
       mode    => '644',
       content => template('sunet/rsyslog/rsyslog-local.conf.erb'),
       require => Package['rsyslog'],
       notify  => Service['rsyslog']
     }

  }

}
