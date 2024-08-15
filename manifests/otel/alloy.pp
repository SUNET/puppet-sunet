# @summary class to setup Grafana Alloy
# @param otel_receiver Where should we send OpenTelemetry data?
class sunet::otel::alloy (
  String $otel_receiver    = undef,
) {
  file { '/etc/apt/keyrings/grafana.gpg' :
    ensure  => 'file',
    notify  => Service['alloy'],
    mode    => '0644',
    group   => 'root',
    content => file( 'sunet/otel/grafana.gpg' ),
  }
  file { '/etc/apt/sources.list.d/grafana.list' :
    ensure  => 'file',
    notify  => Service['alloy'],
    mode    => '0644',
    group   => 'root',
    content => 'deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main',
  }
  exec { 'alloy_update':
    command => 'apt update',
    unless  => 'dpkg -l alloy',
  }
  package { 'alloy':
    ensure => 'installed',
  }
  file { '/etc/alloy' :
    ensure => 'directory',
    notify => Service['alloy'],
    mode   => '0644',
    group  => 'root',
  }
  file { '/etc/alloy/targets.d' :
    ensure => 'directory',
    notify => Service['alloy'],
    mode   => '0644',
    group  => 'root',
  }
  file { '/etc/alloy/config.alloy' :
    ensure  => 'file',
    notify  => Service['alloy'],
    mode    => '0644',
    group   => 'root',
    content => template( 'sunet/otel/config.alloy' ),
  }
  service { 'alloy':
    ensure  => 'running',
    enable  => 'true',
    require => Package['alloy'],
  }
}
