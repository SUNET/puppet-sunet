# Expose the grafana apt repo.
# E.g used for alloy and grafana
define sunet::apt::repo_grafana (
) {

  $distro = $facts['os']['distro']['id']
  $release = $facts['os']['distro']['release']['major']

  if ($distro == 'Debian' and versioncmp($release, '12') <= 0) or ($distro == 'Ubunutu' and versioncmp($release, '22.04') <= 0) {

    apt::source { 'grafana':
        location => 'https://apt.grafana.com',
        repos    => 'main',
        release  => 'stable',
        key      => {
          id      => 'B53AE77BADB630A683046005963FA27710458545',
          name    => 'grafana.gpg',
          content => file('sunet/apt/grafana.gpg'),
        }
    }

  } else {
    apt::source { 'grafana':
        location => 'https://apt.grafana.com',
        repos    => 'main',
        release  => 'stable',
        key      => {
          name    => 'grafana.gpg',
          content => file('sunet/apt/grafana.gpg'),
        }
    }
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
