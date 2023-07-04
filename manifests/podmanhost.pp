# Install docker from https://get.docker.com/ubuntu
class sunet::podmanhost(
) {
  include sunet::packages::podman
  include stdlib
  file { '/etc/containers/storage.conf':
    ensure  => file,
    content => template('sunet/podmanhost/storage.conf.erb'),
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
  }
}
