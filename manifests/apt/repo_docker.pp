# The apt repo for docker
define sunet::apt::repo_docker (
  Enum['stable', 'edge', 'test'] $docker_repo = 'stable',
) {

  $distro    = $facts['os']['distro']['id']
  $lc_distro = downcase($distro)
  $release   = $facts['os']['distro']['release']['major']

  if ($distro == 'Ubuntu' and versioncmp($facts['os']['release']['full'], '24.04') < 0) or
    ($distro == 'Debian' and versioncmp($release, '13') < 0) {
    sunet::misc::create_dir { '/etc/cosmos/apt/keys': owner => 'root', group => 'root', mode => '0755'}
    file { '/etc/cosmos/apt/keys/docker_ce-8D81803C0EBFCD88.pub':
      ensure  => file,
      mode    => '0644',
      content => file('sunet/apt/docker.asc'),
    }
    apt::key { 'docker_ce':
      id     => '9DC858229FC7DD38854AE2D88D81803C0EBFCD88',
      server => 'https://does-not-exists-but-is-required.example.com',
      source => '/etc/cosmos/apt/keys/docker_ce-8D81803C0EBFCD88.pub',
      notify => Exec['dockerhost_apt_get_update'],
    }
    apt::source { 'docker_ce':
      location => "https://download.docker.com/linux/${lc_distro}",
      release  => $facts['os']['distro']['codename'],
      repos    => $docker_repo,
      key      => {'id' => '9DC858229FC7DD38854AE2D88D81803C0EBFCD88'},
      notify   => Exec['dockerhost_apt_get_update'],
    }
  } else {
    # Ubuntu 24.04+ (apt 2.7+) and Debian 13+ removed apt-key support;
    # use a signed-by keyring file instead.
    file { '/etc/apt/keyrings':
      ensure => directory,
      mode   => '0755',
    }
    file { '/etc/apt/keyrings/docker.asc':
      ensure  => file,
      mode    => '0644',
      content => file('sunet/apt/docker.asc'),
      require => File['/etc/apt/keyrings'],
    }
    apt::source { 'docker':
      location => "https://download.docker.com/linux/${lc_distro}",
      repos    => $docker_repo,
      keyring  => '/etc/apt/keyrings/docker.asc',
      notify   => Exec['dockerhost_apt_get_update'],
      require  => File['/etc/apt/keyrings/docker.asc'],
    }
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
