# This class sets up a rsyslog server that listens for UDP messages on the specified port
# - incoming messages are stored in with fromhost template in /var/log/rsyslog/ directory
# - if graylog_servers is provided, incoming messages are also forwarded to the specified servers.
class sunet::rsyslog_server(
  $udp_port,
  $graylog_servers = [],
  $gelf_tag = undef,
) {
  include sunet::rsyslog

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

  file { '/etc/logrotate.d/rsyslog-server':
    ensure  => file,
    mode    => '0644',
    content => template('sunet/rsyslog/rsyslog-server.logrotate.erb'),
  }

  sunet::misc::ufw_allow { "allow-syslog-udp-${udp_port}":
    from  => 'any',
    proto => 'udp',
    port  => $udp_port,
  }
}
