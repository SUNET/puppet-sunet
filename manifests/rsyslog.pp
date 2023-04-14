class sunet::rsyslog(
  $daily_rotation = true,
  $syslog_servers = hiera_array('syslog_servers',[]),
  $relp_syslog_servers = hiera_array('relp_syslog_servers',[]),
  $single_log_file = true,
  $syslog_enable_remote = safe_hiera('syslog_enable_remote','true'),
  $udp_port = hiera('udp_port',undef),
  $udp_client = hiera('udp_client',"any"),
  $tcp_port = hiera('tcp_port',undef),
  $tcp_client = hiera('tcp_client',"any"),
  $traditional_file_format = false,
) {
  include stdlib
  ensure_resource('package', 'rsyslog', {
    ensure => 'installed'
  })

  file { '/etc/rsyslog.conf':
    ensure  => file,
    mode    => '644',
    content => template('sunet/rsyslog/rsyslog.conf.erb'),
    require => Package['rsyslog'],
    notify  => Service['rsyslog']
  }

  $default_template = $single_log_file ?
  {
      true  => 'rsyslog-default-single-logfile.conf.erb',
      false => 'rsyslog-default.conf.erb',
  }
  file { '/etc/rsyslog.d/50-default.conf':
    ensure  => file,
    mode    => '644',
    content => template("sunet/rsyslog/${default_template}"),
    require => Package['rsyslog'],
    notify  => Service['rsyslog']
  }

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

  if ($daily_rotation)
  {
     file { '/etc/logrotate.d/rsyslog':
       ensure  => file,
       mode    => '644',
       content => template('sunet/rsyslog/rsyslog.logrotate.erb'),
     }
  }
  if ($single_log_file == true and $facts['fail2ban_is_enabled'] == 'yes') {
     file { '/etc/fail2ban/jail.d/sshd-rsyslog-single-logfile.conf':
       ensure  => file,
       mode    => '644',
       content => template('sunet/rsyslog/fail2ban-ssh-syslog.conf.erb'),
       notify  => Service['fail2ban'],
     }

  }
}
