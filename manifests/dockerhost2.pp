# Install docker from https://get.docker.com/ubuntu
class sunet::dockerhost2(
  String $docker_version                      = 'installed',
  String $docker_package_name                 = 'docker-ce',
  Enum['stable', 'edge', 'test'] $docker_repo = 'stable',
  Boolean $run_docker_cleanup                 = true,
  String $docker_network                      = lookup('dockerhost_docker_network', String, undef, '172.16.0.0/12'),
  String $docker_network_v6                   = lookup('dockerhost_docker_network_v6', String, undef, 'fd0c:d0c::/64'),  # default bridge
  String $docker_dns                          = lookup('dockerhost_docker_dns', String, undef,'89.32.32.32'),
  Boolean $enable_ipv6                        = true,
  Boolean $nat                                = true,
) {

  include sunet::packages::jq # restart_unhealthy_containers requirement
  include sunet::packages::python3_yaml # check_docker_containers requirement

  if ($nat) {
    file {
      '/etc/nftables/conf.d/200-sunet_dockerhost.nft':
        ensure  => file,
        mode    => '0400',
        content => template('sunet/dockerhost/200-dockerhost2_nftables.nft.erb'),
        notify  => Service['nftables'],
        ;
    }
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

  # Make it possible to not set a class::docker DNS at all by passing in the empty string
  $_docker_dns = $docker_dns ? {
    ''      => undef,
    default => $docker_dns,
  }

  if $tcp_bind and has_key($facts['tls_certificates'], $facts['networking']['fqdn']) and has_key($facts['tls_certificates'][$::fqdn], 'infra_cert') {
    $_tcp_bind = $tcp_bind
    $tls_enable = true
    $tls_cacert = '/etc/ssl/certs/infra.crt'
    $tls_cert   = $facts['tls_certificates'][$::fqdn]['infra_cert']
    $tls_key    = $facts['tls_certificates'][$::fqdn]['infra_key']
  } else {
    $_tcp_bind = undef
    $tls_enable = undef
    $tls_cacert = undef
    $tls_cert = undef
    $tls_key = undef
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
