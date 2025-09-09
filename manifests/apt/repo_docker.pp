# The apt repo for docker
define sunet::apt::repo_docker (
) {

  $distro = $facts['os']['distro']['id']
  $lc_distro = downcase($distro)
  $release = $facts['os']['distro']['release']['major']

  apt::source { 'docker':
    location => "https://download.docker.com/linux/${lc_distro}",
    repos    => 'stable',
    key      => {
      name    => 'docker.asc',
      content => file('sunet/apt/docker.asc'),
    }
    notify   => Exec['dockerhost_apt_get_update'],

  }
  apt::pin { 'Pin docker repo':
    packages => '*',
    priority => 1,
    origin   => 'download.docker.com'
  }

  exec { 'dockerhost_apt_get_update':
    command     => '/usr/bin/apt-get update',
    cwd         => '/tmp',
    refreshonly => true,
  }
}
