# Expose the grafana apt repo.
# E.g used for alloy and grafana
define sunet::apt::repo_alloy (
) {
  }
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
}
