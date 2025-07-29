# rsyslog
class sunet::rsyslog(
  $daily_rotation = true,
  $syslog_servers = lookup(syslog_servers, undef, undef, []),
  $relp_syslog_servers = lookup(relp_syslog_servers, undef, undef, []),
  $single_log_file = true,
  $syslog_enable_remote = lookup('syslog_enable_remote', undef, undef, 'true'),
  $udp_port = lookup(udp_port, undef, undef, undef),
  $udp_client = lookup('udp_client', undef, undef, 'any'),
  $tcp_port = lookup(tcp_port, undef, undef, undef),
  $tcp_client = lookup('tcp_client', undef, undef, 'any'),
  $traditional_file_format = false,
) {
  include stdlib
  ensure_resource('package', 'rsyslog', {
    ensure => 'installed'
  })

  file { '/etc/rsyslog.conf':
    ensure  => file,
    mode    => '0644',
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
    mode    => '0644',
    content => template("sunet/rsyslog/${default_template}"),
    require => Package['rsyslog'],
    notify  => Service['rsyslog']
  }

  $do_remote = str2bool($syslog_enable_remote)

  file { '/etc/rsyslog.d/60-remote.conf':
    ensure  => file,
    mode    => '0644',
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
        sunet::misc::ufw_allow { "allow-syslog-udp-${udp_port}":
          from  => $udp_client,
          proto => 'udp',
          port  => "${udp_port}"
        }
    }

    if ($tcp_port) {
        sunet::misc::ufw_allow { "allow-syslog-tcp-${tcp_port}":
          from  => $tcp_client,
          proto => 'tcp',
          port  => $tcp_port
        }
    }

    file { '/etc/rsyslog.d/50-local.conf':
      ensure  => file,
      mode    => '0644',
      content => template('sunet/rsyslog/rsyslog-local.conf.erb'),
      require => Package['rsyslog'],
      notify  => Service['rsyslog']
    }

  }

  if ($daily_rotation == true)
  {
    file { '/etc/logrotate.d/rsyslog':
      ensure  => file,
      mode    => '0644',
      content => template('sunet/rsyslog/rsyslog.logrotate.erb'),
    }
  }
  if ($single_log_file == true and $facts['fail2ban_is_enabled'] == 'yes') {
    file { '/etc/fail2ban/jail.d/sshd-rsyslog-single-logfile.conf':
      ensure  => file,
      mode    => '0644',
      content => template('sunet/rsyslog/fail2ban-ssh-syslog.conf.erb'),
      notify  => Service['fail2ban'],
    }

  }
}
