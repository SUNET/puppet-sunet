# Install podman from kubic
class sunet::packages::podman(
) {
  include sunet::packages::curl
  include sunet::packages::gpg
  include stdlib

  if $::operatingsystem == 'Ubuntu' {
    $reponame = 'xUbuntu'
  } else {
    $reponame = $::operatingsystem
  }
  exec { 'podman_repo_key':
    creates => '/etc/apt/trusted.gpg.d/libcontainers.gpg',
    command => "curl https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/${reponame}_${::operatingsystemmajrelease}/Release.key | gpg --dearmor > /etc/apt/trusted.gpg.d/libcontainers.gpg",
    unless  => 'test -f /etc/apt/trusted.gpg.d/libcontainers.gpg',
  }
  -> file { 'podman_repo_file':
    ensure  => file,
    name    => '/etc/apt/sources.list.d/libcontainers.list',
    content => "deb https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/${reponame}_${::operatingsystemmajrelease}/ /\n",
  }
  -> exec { 'podman_update':
    command => 'apt update',
    unless  => 'dpkg -l podman'
  }
  -> package { 'podman':
    ensure => latest
  }
}
