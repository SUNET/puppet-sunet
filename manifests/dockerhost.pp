# Install docker from https://get.docker.com/ubuntu
class sunet::dockerhost(
  $docker_version      = "1.8.3-0~${::lsbdistcodename}",
  $run_unbound         = true,
  $run_docker_cleanup  = true,
  $dns_ttl             = '5',  # used in run-parts template
) {

  # Remove old versions, if installed
  package { ['lxc-docker-1.6.2', 'lxc-docker'] :
     ensure => 'purged',
  } ->

  file {'/etc/apt/sources.list.d/docker.list':
     ensure => 'absent',
  }

  apt::source {'docker_official':
     location => 'https://apt.dockerproject.org/repo',
     release  => "ubuntu-${::lsbdistcodename}",
     repos    => 'main',
     key      => '58118E89F3A912897C070ADBF76221572C52609D',
     include  => { 'src' => false },
  } ->

  package { 'docker-engine' :
     ensure => $docker_version,
  }

  # If docker was just installed, facter will not know the IP of docker0. Thus the pick.
  # Get default address from Hiera since it is different in Docker 1.8 and 1.9.
  $docker_dns = $run_unbound ? {
    true  => pick($::ipaddress_docker0, hiera('dockerhost_ip', '172.17.0.1')),
    false => undef,
  }

  class {'docker':
     manage_package              => false,
     use_upstream_package_source => false,
     dns                         => $docker_dns,
  }

  file {
    '/usr/local/etc/docker.d':
      ensure  => 'directory',
      mode    => '0755',
      ;
    '/usr/local/etc/docker.d/docker_pre-start':
      ensure  => file,
      mode    => '0755',
      content => template('sunet/dockerhost/docker_pre-start.erb'),
      ;
    '/usr/local/etc/docker.d/docker_post-start':
      ensure  => file,
      mode    => '0755',
      content => template('sunet/dockerhost/docker_post-start.erb'),
      ;
    '/usr/local/etc/docker.d/docker_pre-stop':
      ensure  => file,
      mode    => '0755',
      content => template('sunet/dockerhost/docker_pre-stop.erb'),
      ;
    '/usr/local/etc/docker.d/docker_post-stop':
      ensure  => file,
      mode    => '0755',
      content => template('sunet/dockerhost/docker_post-stop.erb'),
      ;
    '/etc/logrotate.d/docker-containers':
      ensure  => file,
      path    => '/etc/logrotate.d/docker-containers',
      mode    => '0644',
      content => template('sunet/dockerhost/logrotate_docker-containers.erb'),
      ;
    '/etc/scriptherder/check/docker-cleanup.ini':
      ensure  => file,
      mode    => '0644',
      content => template('sunet/dockerhost/scriptherder_docker-cleanup.ini.erb'),
      ;
    '/etc/sudoers.d/nrpe_dockerhost_checks':
      ensure  => file,
      mode    => '0440',
      content => template('sunet/dockerhost/etc_sudoers.d_nrpe_dockerhost_checks.erb'),
      ;
    '/usr/local/bin/get_docker_bridge':
      ensure  => file,
      mode    => '0755',
      content => template('sunet/dockerhost/get_docker_bridge.erb'),
      ;
    }

  # Remove obsolete files installed earlier
  file { ['/usr/local/bin/verify_docker_image',
          '/usr/local/bin/sunet_docker_pre-post',  # replaced by run-parts scripts above
          '/usr/local/bin/tarmangel',
          '/etc/unbound/unbound.conf.d/docker.conf',  # moved to unbound docker container
          ]:
    ensure => 'absent',
  }

  each(['tcp', 'udp']) |$proto| {
    # Allow Docker containers resolving using caching resolver running on docker host
    ufw::allow { "allow-docker-resolving_${proto}":
      port  => '53',
      ip    => pick($::ipaddress_docker0, '172.17.0.1'),
      from  => '172.16.0.0/12',
      proto => $proto,
    }
  }

  if $run_docker_cleanup {
    # Cron job to remove old unused docker images
    cron { "dockerhost_cleanup":
      command  => "test -x /usr/local/bin/scriptherder && test -x /usr/local/bin/docker-cleanup && /usr/local/bin/scriptherder --mode wrap --syslog --name docker-cleanup -- /usr/local/bin/docker-cleanup",
      user     => 'root',
      special  => 'daily',
    }
  }

  if $run_unbound {
    file {
      '/etc/unbound/unbound.conf.d/unbound.conf':  # configuration to forward queries to .docker to the docker-unbound
        ensure  => file,
        path    => '/etc/unbound/unbound.conf.d/unbound.conf',
        mode    => '0644',
        content => template('sunet/dockerhost/unbound.conf.erb'),
        notify  => Service['unbound'],
        ;
    }

    sunet::docker_run { 'unbound':
      image   => 'docker.sunet.se/eduid/unbound',
      volumes => ['/etc/unbound/unbound_control.key:/etc/unbound/unbound_control.key:ro',
                  '/etc/unbound/unbound_control.pem:/etc/unbound/unbound_control.pem:ro',
                  '/etc/unbound/unbound_server.key:/etc/unbound/unbound_server.key:ro',
                  '/etc/unbound/unbound_server.pem:/etc/unbound/unbound_server.pem:ro',
                  '/dev/log:/dev/log',
                  ],
      net      => 'host',  # unbound needs to bind to the Docker IP
      env      => ["unbound_interface=${::ipaddress_docker0}"],
    }
  }

}
