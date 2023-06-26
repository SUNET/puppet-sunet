# Install docker from https://get.docker.com/ubuntu
class sunet::dockeriohost(
) {
  include stdlib

  if $::facts['sunet_nftables_enabled'] == 'yes' {
    # Hackishly create the /etc/systemd/system/docker.service.d/ directory before the docker service is installed.
    # If we do this using 'file', the docker class will fail because of a duplicate declaration.
    exec { 'create_dockerio_service_dir':
      command => '/bin/mkdir -p /etc/systemd/system/docker.service.d/',
      unless  => '/usr/bin/test -d /etc/systemd/system/docker.service.d/',
    }
    # The nftables ns dropin file must be in place before the docker service is installed on a new host,
    # otherwise the docker0 interface will be created and interfere until reboot.
    file {
      '/etc/systemd/system/docker.service.d/docker_nftables_ns.conf':
        ensure  => file,
        mode    => '0444',
        content => template('sunet/dockerhost/systemd_dropin_nftables_ns.conf.erb'),
        notify  => Service['docker'],
    }
    file {
      '/etc/nftables/conf.d/200-sunet_dockerhost.nft':
        ensure  => file,
        mode    => '0400',
        content => template('sunet/dockerhost/200-dockerhost_nftables.nft.erb'),
        notify  => Service['nftables'],
    }
  } else {
    file {
      '/etc/nftables/conf.d/200-sunet_dockerhost.nft':
        ensure  => absent,
    }
    -> file {
      '/etc/systemd/system/docker.service.d/docker_nftables_ns.conf':
        ensure  => absent,
    }
    -> exec { 'remove_dockerio_service_dir':
      command => 'rmdir /etc/systemd/system/docker.service.d/',
      onlyif  => 'ls -A /etc/systemd/system/docker.service.d/*',
    }
  }
  package { 'docker.io' :
    ensure  => latest,
  }
  package { 'docker-compose' :
    ensure  => latest,
  }
}
