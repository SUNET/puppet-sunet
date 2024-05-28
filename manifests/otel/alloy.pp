# @summary class to setup Grafana Alloy
# @param otel_receiver Where should we send OpenTelemetry data?
class sunet::otel::alloy (
  String $otel_receiver    = undef,
) {
  $nagios_ip_v4 = lookup('nagios_ip_v4', undef, undef, '109.105.111.111')
  $nagios_ip_v6 = lookup('nagios_ip_v6', undef, undef, '2001:948:4:6::111')
  $nrpe_clients = lookup('nrpe_clients', undef, undef, ['127.0.0.1','127.0.1.1',$nagios_ip_v4,$nagios_ip_v6])
  $allowed_hosts = join($nrpe_clients,',')

  file { '/etc/apt/keyrings/grafana.gpg' :
    ensure  => 'file',
    notify  => Service['alloy'],
    mode    => '0644',
    group   => 'root',
    require => Package['alloy'],
    content => file( 'sunet/otel/grafana.gpg' ),
  }
  file { '/etc/apt/sources.list.d/grafana.list' :
    ensure  => 'file',
    notify  => Service['alloy'],
    mode    => '0644',
    group   => 'root',
    require => Package['alloy'],
    content => 'deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main',
  }
  file { '/etc/alloy/config.alloy' :
    ensure  => 'file',
    notify  => Service['alloy'],
    mode    => '0644',
    group   => 'root',
    require => Package['alloy'],
    content => template( 'sunet/otel/config.alloy' ),
  }
  package { 'alloy':
    ensure => 'installed',
  }
  -> service { 'alloy':
    ensure  => 'running',
    enable  => 'true',
    require => Package['alloy'],
  }
}
