# Expose the grafana apt repo.
# E.g used for alloy and grafana
define sunet::apt::repo_grafana (
) {
  file { '/etc/apt/keyrings' :
    ensure => 'directory',
    mode   => '0644',
    group  => 'root'
  }
  file { '/etc/apt/keyrings/grafana.gpg' :
    ensure  => 'file',
    mode    => '0644',
    group   => 'root',
    content => file( 'sunet/apt/grafana.gpg' ),
  }
  file { '/etc/apt/sources.list.d/grafana.list' :
    ensure  => 'file',
    mode    => '0644',
    group   => 'root',
    content => 'deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main',
  }
  include sunet::security::unattended_upgrades
  if ($sunet::security::unattended_upgrades::use_template) {
    concat::fragment { 'origin_grafana':
      target  => '/etc/apt/apt.conf.d/51unattended-upgrades-origins',
      content => '"site=apt.grafana.com,a=stable";' # lint:ignore:single_quote_string_with_variables
    }
  }
}
