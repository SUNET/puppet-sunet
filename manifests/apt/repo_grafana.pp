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

  $origins_from_template = '/etc/apt/apt.conf.d/51unattended-upgrades-origins'
  # This might be a race on first run depending on exection order but it's the best I can come up with at the time. Sorry.
  if (find_file($origins_from_template)) {
    concat::fragment { 'origin_grafana':
      target  => $origins_from_template,
      content => '"site=apt.grafana.com,a=stable";' # lint:ignore:single_quote_string_with_variables
    }
  } else {
    warning("Unattended upgrades not configured or not configured to use templates. The grafana products won't get any automatic updates.")
  }
}
