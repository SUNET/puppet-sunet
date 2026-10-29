# Install podman-compose from pip
class sunet::packages::podman_compose(
) {
  include sunet::packages::pip
  include stdlib

  exec { 'podman-compose':
    command => 'python3 -m pip install podman-compose',
    unless  => 'test -f /usr/local/bin/podman-compose',
  }

}
