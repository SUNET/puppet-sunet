# Install docker from https://get.docker.com/ubuntu
class sunet::dockerhost(
  $docker_version            = "1.10.3-0~${::lsbdistcodename}",
  $docker_extra_parameters   = undef,
  $run_docker_cleanup        = true,
  $docker_network            = hiera('dockerhost_docker_network', '172.18.0.0/22'),
  $docker_dns                = pick($::ipaddress_eth0, $::ipaddress_bond0, $::ipaddress_br0, $::ipaddress_em1, $::ipaddress_em2,
                                    $::ipaddress6_eth0, $::ipaddress6_bond0, $::ipaddress6_br0, $::ipaddress6_em1, $::ipaddress6_em2,
                                    $::ipaddress, $::ipaddress6,
                                    ),
  $ufw_allow_docker_dns      = true,
  $manage_dockerhost_unbound = false,
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
     key      => { 'id'     => '58118E89F3A912897C070ADBF76221572C52609D',
                   'server' => 'keyserver.ubuntu.net' },
     include  => { 'src' => false },
  } ->

  package { 'docker-engine' :
     ensure => $docker_version,
  }

  class {'docker':
     manage_package              => false,
     use_upstream_package_source => false,
     dns                         => $docker_dns,
     extra_parameters            => $docker_extra_parameters,
  } ->

  docker_network { 'docker':  # default network for containers
    ensure => 'present',
    subnet => $docker_network,
  }

  file {
    '/usr/local/etc/docker.d':  # XXX obsolete
      ensure  => 'directory',
      mode    => '0755',
      ;
    '/etc/logrotate.d':
      ensure  => 'directory',
      mode    => '0755',
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
    '/usr/local/bin/check_docker_containers':
      ensure  => file,
      mode    => '0755',
      content => template('sunet/dockerhost/check_docker_containers.erb'),
      ;
    }

  # Remove obsolete files installed earlier
  file { ['/usr/local/bin/verify_docker_image',
          '/usr/local/bin/sunet_docker_pre-post',  # replaced by run-parts scripts above
          '/usr/local/bin/tarmangel',
          '/etc/unbound/unbound.conf.d/docker.conf',  # moved to unbound docker container
          '/usr/local/etc/docker.d/docker_pre-start',
          '/usr/local/etc/docker.d/docker_post-start',
          '/usr/local/etc/docker.d/docker_pre-stop',
          '/usr/local/etc/docker.d/docker_post-stop',
          '/usr/local/bin/get_docker_bridge',
          '/usr/local/bin/get_docker_networkmode'
          ]:
    ensure => 'absent',
  }

  if $run_docker_cleanup {
    # Cron job to remove old unused docker images
    cron { "dockerhost_cleanup":
      command  => "test -x /usr/local/bin/scriptherder && test -x /usr/local/bin/docker-cleanup && /usr/local/bin/scriptherder --mode wrap --syslog --name docker-cleanup -- /usr/local/bin/docker-cleanup",
      user     => 'root',
      special  => 'daily',
    }
  }

  if $ufw_allow_docker_dns {
    if $docker_dns =~ /^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$/ {
      # Allow Docker containers resolving using caching resolver running on docker host
      each(['tcp', 'udp']) |$proto| {
        ufw::allow { "dockerhost_ufw_allow_dns_53_${proto}":
          from  => '172.16.0.0/12',
          ip    => $docker_dns,
          port  => '53',
          proto => $proto,
        }
      }
    } else {
      notice("Can't set up firewall rules to allow v4-docker DNS to a v6 nameserver ($docker_dns)")
    }
  }

  if $manage_dockerhost_unbound {
    ensure_resource('class', 'sunet::unbound', {})

    file {
      '/etc/unbound/unbound.conf.d/unbound.conf':  # configuration to listen to the $docker_dns IP
        ensure  => file,
        path    => '/etc/unbound/unbound.conf.d/unbound.conf',
        mode    => '0644',
        content => template('sunet/dockerhost/unbound.conf.erb'),
        require => Package['unbound'],
        notify  => Service['unbound'],
        ;
    }
  }

}
