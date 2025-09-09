# Install docker from https://get.docker.com/ubuntu
class sunet::dockerhost(
  String $docker_version                      = 'installed',
  String $docker_package_name                 = 'docker-ce',  # facilitate transition to new docker-ce package
  Enum['stable', 'edge', 'test'] $docker_repo = 'stable',
  $storage_driver                             = undef,
  $docker_extra_parameters                    = undef,
  Boolean $run_docker_cleanup                 = true,
  Variant[String, Boolean] $docker_network    = lookup('dockerhost_docker_network', Variant[String, Boolean], undef, '172.18.0.0/22'),
  String $docker_network_v6                   = lookup('dockerhost_docker_network_v6', String, undef, 'fd0c:d0c::/64'),  # default bridge
  Variant[String, Array[String]] $docker_dns  = $facts['networking']['ip'],
  Boolean $ufw_allow_docker_dns               = true,
  Boolean $manage_dockerhost_unbound          = false,
  String $compose_image                       = 'docker.sunet.se/library/docker-compose',
  String $compose_version                     = '1.24.0',
  Optional[Array[String]] $tcp_bind           = undef,
  Boolean $write_daemon_config                = false,
  Boolean $enable_ipv6                        = false,
  Boolean $advanced_network                   = false,
) {

  $container_name_delimiter = '_'

  include sunet::packages::jq # restart_unhealthy_containers requirement
  include sunet::packages::python3_yaml # check_docker_containers requirement
  include stdlib

  if $::facts['sunet_nftables_enabled'] == 'yes' and $advanced_network == false {
    # Hackishly create the /etc/systemd/system/docker.service.d/ directory before the docker service is installed.
    # If we do this using 'file', the docker class will fail because of a duplicate declaration.
    exec { "create_${name}_service_dir":
      command => '/bin/mkdir -p /etc/systemd/system/docker.service.d/',
      unless  => '/usr/bin/test -d /etc/systemd/system/docker.service.d/',
    }
    # The nftables ns dropin file must be in place bedore the docker service is installed on a new host,
    # otherwise the docker0 interface will be created and interfere until reboot.
    #
    file {
      '/etc/systemd/system/docker.service.d/docker_nftables_ns.conf':
        ensure  => file,
        mode    => '0444',
        content => template('sunet/dockerhost/systemd_dropin_nftables_ns.conf.erb'),
        ;
    }

    if ! has_key($::facts['networking']['interfaces'], 'to_docker') {
      # Have to check if the Docker service has been (re-)started yet with the nftables ns dropin file in place.
      # If not, there won't be a to_docker interface, and we can't set up the firewall rules.
      notice('No to_docker interface found, not setting up the firewall rules for Docker (will probably work next time)')
    } else {
      file {
        '/etc/nftables/conf.d/200-sunet_dockerhost.nft':
          ensure  => file,
          mode    => '0400',
          content => template('sunet/dockerhost/200-dockerhost_nftables.nft.erb'),
          notify  => Service['nftables'],
          ;
      }
    }
  }

  if versioncmp($facts['os']['release']['full'], '22.04') <= 0 or $facts['os']['name'] == 'Debian' {
    # Remove old versions, if installed
    package { ['lxc-docker-1.6.2', 'lxc-docker'] :
      ensure => 'purged',
    }

    file {'/etc/apt/sources.list.d/docker.list':
      ensure => 'absent',
    }

    if $docker_package_name != 'docker-engine' and $docker_package_name != 'docker.io' {
      # transisition to docker-ce
      exec { 'remove_dpkg_arch_i386':
        command => '/usr/bin/dpkg --remove-architecture i386',
        onlyif  => '/usr/bin/dpkg --print-foreign-architectures | grep i386',
      }

      package {'docker-engine': ensure => 'purged'}
    }

    # Add the dockerproject repository, then force an apt-get update before
    # trying to install the package. See https://tickets.puppetlabs.com/browse/MODULES-2190.
    #
    sunet::misc::create_dir { '/etc/cosmos/apt/keys': owner => 'root', group => 'root', mode => '0755'}
    file {
      '/etc/cosmos/apt/keys/docker_ce-8D81803C0EBFCD88.pub':
        ensure  => file,
        mode    => '0644',
        content => file('sunet/docker/docker.asc'),
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
  }

  apt::pin { 'Pin docker repo':
    packages => '*',
    priority => 1,
    origin   => 'download.docker.com'
  }
  # Clean up old pinning
  file {'/etc/apt/preferences.d/docker-ce-cli.pref':
    ensure => 'absent',
  }
  file {'/etc/apt/preferences.d/docker_package.pref':
    ensure => 'absent',
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

  # This is an approximation about how to enable IPv6 in Docker, but
  # BEWARE! IPv6 is currently utterly dysfunctional in docker-compose (version 3 / 1.29.2). Sigh.
  #
  $ipv6_parameters = ($enable_ipv6 and ! $write_daemon_config) ? {
    true => ['--ipv6',
      $docker_network_v6 ? {
        true => [],
        default => ['--fixed-cidr-v6', $docker_network_v6],
      }
    ],
    false => []
  }

  $_extra_parameters = flatten([
    $docker_extra_parameters,
    $ipv6_parameters,
    ]).join(' ')

  $iptables = $advanced_network ? {
    true      => false,
    false     => true,
  }

  if $write_daemon_config {
    if $docker_network =~ String[1] {
      $default_address_pools = $docker_network
    } else {
      $default_address_pools = '172.16.0.0/12'
    }
    file {
      '/etc/docker':
        ensure => 'directory',
        mode   => '0755',
        ;
      '/etc/docker/daemon.json':
        ensure  => file,
        mode    => '0644',
        content => template('sunet/dockerhost/daemon.json.erb'),
        ;
    }

    # Docker rejects options specified both from command line and in daemon.json
    class {'docker':
      ip_forward                  => $iptables,
      ip_masq                     => $iptables,
      iptables                    => $iptables,
      manage_package              => false,
      manage_kernel               => false,
      use_upstream_package_source => false,
      extra_parameters            => $_extra_parameters,
      docker_command              => 'dockerd',
      daemon_subcommand           => '',
      require                     => Package[$docker_package_name],
    }
  } else {
    class {'docker':
      ip_forward                  => $iptables,
      ip_masq                     => $iptables,
      iptables                    => $iptables,
      storage_driver              => $storage_driver,
      manage_package              => false,
      manage_kernel               => false,
      use_upstream_package_source => false,
      dns                         => $_docker_dns,
      extra_parameters            => $_extra_parameters,
      docker_command              => 'dockerd',
      daemon_subcommand           => '',
      tcp_bind                    => $_tcp_bind,
      tls_enable                  => $tls_enable,
      tls_cacert                  => $tls_cacert,
      tls_cert                    => $tls_cert,
      tls_key                     => $tls_key,
      require                     => Package[$docker_package_name],
    }
  }

  if $docker_network =~ String {
    # Create a useful default network bridge for containers.
    #
    # Docker DNS isn't available on the default 'bridge' interface, so another
    # bridge interface is needed for containers benefiting from the DNS resolution
    # but not running using docker-compose.
    docker_network { 'docker':
      ensure  => 'present',
      subnet  => $docker_network,
      require => Class['docker'],
    }
  } elsif $docker_network == true {
    # Create a docker network, but don't specify the subnet.
    docker_network { 'docker':
      ensure  => 'present',
      require => Class['docker'],
    }
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
    '/usr/local/bin/docker-compose':
      mode    => '0755',
      content => template('sunet/dockerhost/docker-compose.erb'),
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

  if $ufw_allow_docker_dns {
    if is_ipaddr($docker_dns, 4) {
      # Allow Docker containers resolving using caching resolver running on docker host
      sunet::misc::ufw_allow { 'dockerhost_dns':
          from  => '172.16.0.0/12',
          to    => $docker_dns,
          port  => '53',
          proto => ['tcp', 'udp'],
      }
    } else {
      notice("Can't set up firewall rules to allow v4-docker DNS to a v6 nameserver (${docker_dns})")
    }
  }

  if $manage_dockerhost_unbound {
    ensure_resource('class', 'sunet::unbound', { disable_resolved_stub => true, })

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
