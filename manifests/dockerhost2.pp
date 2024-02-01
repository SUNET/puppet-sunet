# Install docker from https://get.docker.com/ubuntu
class sunet::dockerhost2(
  String $docker_version                      = 'installed',
  String $docker_package_name                 = 'docker-ce',
  Enum['stable', 'edge', 'test'] $docker_repo = 'stable',
  Boolean $run_docker_cleanup                 = true,
  String $docker_network                      = lookup('dockerhost_docker_network', String, undef, '172.16.0.0/12'),
  String $docker_network_v6                   = lookup('dockerhost_docker_network_v6', String, undef, 'fd0c:d0c::/64'),  # default bridge
  Variant[String,Boolean] $docker_dns         = lookup('dockerhost_docker_dns', undef, undef,false),
  Boolean $ipv6                               = true,
  Boolean $nat                                = true,
  Boolean $live_restore                       = false,
) {

  include sunet::packages::jq # restart_unhealthy_containers requirement
  include sunet::packages::python3_yaml # check_docker_containers requirement


  # Start of Migration from sunet::dockerhost
  file {'/etc/systemd/system/docker.service.d/docker_nftables_ns.conf':
    ensure => 'absent',
  }
  file {'/etc/systemd/system/docker.service.d/service-overrides.conf':
    ensure => 'absent',
  }
  file {'/etc/default/docker':
    ensure => 'absent',
  }
  # End of Migration from sunet::dockerhost

  if ($nat) {
    file {
      '/etc/nftables/conf.d/200-sunet_dockerhost.nft':
        ensure  => file,
        mode    => '0400',
        content => template('sunet/dockerhost/200-dockerhost2_nftables.nft.erb'),
        notify  => Service['nftables'],
        ;
    }
  } else {
    file {'/etc/nftables/conf.d/200-sunet_dockerhost.nft':
      ensure => 'absent',
      notify => Service['nftables'],
    }
  }

  file {
    '/etc/docker':
      ensure => 'directory',
      mode   => '0755',
      ;
    '/etc/docker/daemon.json':
      ensure  => file,
      mode    => '0644',
      content => template('sunet/dockerhost/daemon2.json.erb'),
      ;
  }

  # Add the dockerproject repository, then force an apt-get update before
  # trying to install the package. See https://tickets.puppetlabs.com/browse/MODULES-2190.
  #
  sunet::misc::create_dir { '/etc/cosmos/apt/keys': owner => 'root', group => 'root', mode => '0755'}
  file {
    '/etc/cosmos/apt/keys/docker_ce-8D81803C0EBFCD88.pub':
      ensure  => file,
      mode    => '0644',
      content => template('sunet/dockerhost/docker_ce-8D81803C0EBFCD88.pub.erb'),
      ;
    }
  apt::key { 'docker_ce':
    id     => '9DC858229FC7DD38854AE2D88D81803C0EBFCD88',
    server => 'https://does-not-exists-but-is-required.example.com',
    source => '/etc/cosmos/apt/keys/docker_ce-8D81803C0EBFCD88.pub',
    notify => Exec['dockerhost_apt_get_update'],
  }

  $distro = downcase($facts['os']['name'])
  # new source
  apt::source {'docker_ce':
    location => "https://download.docker.com/linux/${distro}",
    release  => $facts['os']['distro']['codename'],
    repos    => $docker_repo,
    key      => {'id' => '9DC858229FC7DD38854AE2D88D81803C0EBFCD88'},
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

  package { $docker_package_name :
    ensure  => $docker_version,
    require => Exec['dockerhost_apt_get_update'],
  }
  package { 'docker-ce-cli' :
    ensure  => $docker_version,
    require => Exec['dockerhost_apt_get_update'],
  }

  file {
    '/etc/logrotate.d':
      ensure => 'directory',
      mode   => '0755',
      ;
    '/etc/logrotate.d/docker-containers':
      ensure  => file,
      path    => '/etc/logrotate.d/docker-containers',
      mode    => '0644',
      content => template('sunet/dockerhost/logrotate_docker-containers.erb'),
      ;
    }

    file { '/usr/local/bin/docker-upgrade':
        ensure => 'present',
        mode   => '0755',
        source => 'puppet:///modules/sunet/docker/docker-upgrade',
    }

  if $facts['sunet_has_nrpe_d'] == 'yes' {
    # variables used in etc_sudoers.d_nrpe_dockerhost_checks.erb / nagios_nrpe_checks.erb
    $check_docker_containers_args = '--systemd'

    file {
      '/etc/sudoers.d/nrpe_dockerhost_checks':
        ensure  => file,
        mode    => '0440',
        content => template('sunet/dockerhost/etc_sudoers.d_nrpe_dockerhost_checks.erb'),
        ;
      '/etc/nagios/nrpe.d/sunet_dockerhost_checks.cfg':
        ensure  => 'file',
        content => template('sunet/dockerhost/nagios_nrpe_checks.erb'),
        notify  => Service['nagios-nrpe-server'],
        ;
      '/usr/local/bin/check_docker_containers':
        ensure  => file,
        mode    => '0755',
        content => template('sunet/dockerhost/check_docker_containers.erb'),
        ;
      '/usr/local/bin/restart_unhealthy_containers':
        ensure  => file,
        mode    => '0755',
        content => template('sunet/dockerhost/restart_unhealthy_containers.erb'),
        ;
      '/usr/local/bin/check_for_updated_docker_image':
        ensure  => file,
        mode    => '0755',
        content => template('sunet/dockerhost/check_for_updated_docker_image.erb'),
        ;
    }
  }

  if $run_docker_cleanup {
    # Cron job to remove old unused docker images
    sunet::scriptherder::cronjob { 'dockerhost_cleanup':
      cmd           => join([
        'docker run --rm -v /var/run/docker.sock:/var/run/docker.sock',
        'docker.sunet.se/sunet/docker-custodian dcgc',
        '--exclude-image \'*:latest\'',
        '--exclude-image \'*:staging\'',
        '--exclude-image \'*:stable\'',
        '--exclude-image \'*:*-staging\'',
        '--exclude-image \'*:*-production\'',
        '--max-image-age 24h',
      ], ' '),
      special       => 'daily',
      ok_criteria   => ['exit_status=0', 'max_age=25h'],
      warn_criteria => ['exit_status=0', 'max_age=49h'],
    }
  }

}
