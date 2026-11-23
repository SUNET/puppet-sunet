# This class sets up a rsyslog server that listens for UDP messages on the specified port
# - incoming messages are stored in with fromhost template in /var/log/rsyslog/ directory
# - if graylog_servers is provided, incoming messages are also forwarded to the specified servers.
# - gelf_tag, if set, is added to the GELF messages in the field gelf_tag_field (default _tag).
# - syslog_enable_remote (default false) controls forwarding of the server's own logs to syslog_servers.
# - log files older than retention_days (default 14) are removed.
# - scriptherder_rotation (default false) runs logrotate from a monitored scriptherder cronjob.
class sunet::rsyslog_server(
  $udp_port,
  $graylog_servers = [],
  $gelf_tag = undef,
  $gelf_tag_field = '_tag',
  $retention_days = 14,
  Boolean $scriptherder_rotation = false,
  $syslog_enable_remote = lookup('syslog_enable_remote', undef, undef, 'false'),
) {
  class { 'sunet::rsyslog':
    syslog_enable_remote => $syslog_enable_remote,
  }

  file { '/etc/rsyslog.d/05-templates.conf':
    ensure  => file,
    mode    => '0644',
    content => template('sunet/rsyslog/rsyslog-templates.conf.erb'),
    require => Package['rsyslog'],
    notify  => Service['rsyslog'],
  }

  file { '/etc/rsyslog.d/10-server.conf':
    ensure  => file,
    mode    => '0644',
    content => template('sunet/rsyslog/rsyslog-server.conf.erb'),
    require => File['/etc/rsyslog.d/05-templates.conf'],
    notify  => Service['rsyslog'],
  }

  file { '/var/log/rsyslog':
    ensure => directory,
    owner  => 'root',
    group  => 'adm',
    mode   => '0755',
  }

  # Log files are named per host and day, so logrotate never ages them out
  tidy { '/var/log/rsyslog':
    age     => "${retention_days}d",
    type    => 'mtime',
    recurse => 2,
    matches => '*.log*',
    rmdirs  => false,
    require => File['/var/log/rsyslog'],
  }

  # With scriptherder_rotation, logrotate runs from a monitored cronjob instead of the system logrotate
  $logrotate_conf = $scriptherder_rotation ? {
    true    => '/etc/sunet-rsyslog-server.logrotate',
    default => '/etc/logrotate.d/rsyslog-server',
  }

  file { $logrotate_conf:
    ensure  => file,
    mode    => '0644',
    content => template('sunet/rsyslog/rsyslog-server.logrotate.erb'),
  }

  if $scriptherder_rotation {
    file { '/etc/logrotate.d/rsyslog-server':
      ensure => absent,
    }

    sunet::scriptherder::cronjob { 'rotate_rsyslog_server_logs':
      cmd           => "/usr/sbin/logrotate -s /var/lib/logrotate/sunet-rsyslog-server.status ${logrotate_conf}",
      special       => 'daily',
      ok_criteria   => ['exit_status=0', 'max_age=48h'],
      warn_criteria => ['exit_status=0', 'max_age=96h'],
      require       => File[$logrotate_conf],
    }
  }

  sunet::misc::ufw_allow { "allow-syslog-udp-${udp_port}":
    from  => 'any',
    proto => 'udp',
    port  => $udp_port,
  }
}
