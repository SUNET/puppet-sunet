# @summary class to setup Grafana Alloy
# @param otel_receiver   Where should we send OpenTelemetry data?
# @param enabled         Possibility to opt out from sending otel data (if you for example enable it globally in a repo)
class sunet::otel::alloy (
  String  $otel_receiver    = undef,
  Boolean $enabled          = true,
) {

  if $enabled {
    ensure_resource('sunet::apt::repo_grafana', 'sunet-otel-alloy-grafana-repo')

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
    file { '/etc/alloy/targets.d/example.yaml' :
      ensure  => 'file',
      notify  => Service['alloy'],
      mode    => '0644',
      group   => 'root',
      content => template( 'sunet/otel/example.yaml' ),
    }
    file { '/etc/alloy/config.alloy' :
      ensure  => 'file',
      notify  => Service['alloy'],
      mode    => '0644',
      group   => 'root',
      content => template( 'sunet/otel/config.alloy' ),
    }
    # Extra command line arguments for Alloy. The packaged unit reads CUSTOM_ARGS
    # from /etc/default/alloy (a dpkg conffile); a systemd drop-in loads this file
    # after it instead, so the packaged file can stay untouched.
    # --disable-reporting stops the anonymous usage reports to Grafana Labs, and
    # with them the "reporting Alloy stats"/"usage report sent" log lines.
    include sunet::systemd_reload
    file { '/etc/alloy/sunet.env' :
      ensure  => 'file',
      notify  => Service['alloy'],
      mode    => '0644',
      group   => 'root',
      content => "# Managed by Puppet (sunet::otel::alloy)\nCUSTOM_ARGS=\"--disable-reporting\"\n",
    }
    file { '/etc/systemd/system/alloy.service.d' :
      ensure => 'directory',
      mode   => '0755',
      group  => 'root',
    }
    file { '/etc/systemd/system/alloy.service.d/sunet.conf' :
      ensure  => 'file',
      notify  => [Class['sunet::systemd_reload'], Service['alloy']],
      mode    => '0644',
      group   => 'root',
      content => "# Managed by Puppet (sunet::otel::alloy)\n[Service]\nEnvironmentFile=/etc/alloy/sunet.env\n",
    }
    service { 'alloy':
      ensure  => 'running',
      enable  => 'true',
      require => [Package['alloy'], Class['sunet::systemd_reload']],
    }
    sunet::nftables::allow { 'allow_local_opentelemetry_grpc':
      from => '172.16.0.0/12',
      port => '4317',
    }
    sunet::nftables::allow { 'allow_local_opentelemetry_http':
      from => '172.16.0.0/12',
      port => '4318',
    }
  }
}
