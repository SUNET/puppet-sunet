# Install docker from https://get.docker.com/ubuntu
class sunet::dockerhost(
  String $docker_version,
  String $docker_package_name                 = 'docker-engine',  # facilitate transition to new docker-ce package
  Enum['stable', 'edge', 'test'] $docker_repo = 'stable',
  $storage_driver                             = undef,
  $docker_extra_parameters                    = undef,
  Boolean $run_docker_cleanup                 = true,
  Variant[String, Boolean] $docker_network    = hiera('dockerhost_docker_network', '172.18.0.0/22'),
  String $docker_network_v6                   = hiera('dockerhost_docker_network_v6', 'fd0c::/16'),
  Variant[String, Array[String]] $docker_dns  = $::ipaddress_default,
  Boolean $ufw_allow_docker_dns               = true,
  Boolean $manage_dockerhost_unbound          = false,
  String $compose_image                       = 'docker.sunet.se/library/docker-compose',
  String $compose_version                     = '1.15.0',
  Optional[Array[String]] $tcp_bind           = undef,
  Boolean $write_daemon_config                = false,
  Boolean $enable_ipv6                        = false,
) {

  # Remove old versions, if installed
  package { ['lxc-docker-1.6.2', 'lxc-docker'] :
    ensure => 'purged',
  }

  file {'/etc/apt/sources.list.d/docker.list':
    ensure => 'absent',
  }

  if $docker_package_name != 'docker-engine' {
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
      content => template('sunet/dockerhost/docker_ce-8D81803C0EBFCD88.pub.erb'),
      ;
    }
  apt::key { 'docker_ce':
    id     => '9DC858229FC7DD38854AE2D88D81803C0EBFCD88',
    source => '/etc/cosmos/apt/keys/docker_ce-8D81803C0EBFCD88.pub',
  }

  if $::operatingsystem == 'Ubuntu' and $::operatingsystemrelease == '14.04' {
    $architecture = 'amd64'
  } else {
    $architecture = undef
  }

  # new source
  apt::source {'docker_ce':
    location     => 'https://download.docker.com/linux/ubuntu',
    release      => $::lsbdistcodename,
    repos        => $docker_repo,
    key          => {'id' => '9DC858229FC7DD38854AE2D88D81803C0EBFCD88'},
    architecture => $architecture,
  }

  if $docker_version =~ /^\d.*/ {
    # if it looks like a version number (as opposed to 'latest', 'installed', ...)
    # then pin it so that automatic/manual dist-upgrades don't touch the docker package
    apt::pin { 'docker-ce':
      packages => $docker_package_name,
      version  => $docker_version,
      priority => 920,  # upgrade, but do not downgrade
      notify   => Exec['dockerhost_apt_get_update'],
    }
  }

  exec { 'dockerhost_apt_get_update':
    command     => '/usr/bin/apt-get update',
    cwd         => '/tmp',
    require     => [Apt::Key['docker_ce']],
    subscribe   => [Apt::Key['docker_ce']],
    refreshonly => true,
  }

  package { $docker_package_name :
    ensure  => $docker_version,
    require => Exec['dockerhost_apt_get_update'],
  }

  if $docker_package_name == 'docker-ce' {
    # also need to hold the docker-ce-cli package at the same version
    if $docker_version =~ /^\d.*/ and $docker_version !~ /^1[78]/ and $docker_version !~ /5:18.0[12345678]/ {
      notice("Docker version ${docker_version} has a docker-ce-cli package, pinning it")
      apt::pin { 'docker-ce-cli':
        packages => 'docker-ce-cli',
        version  => $docker_version,
        priority => 920,  # upgrade, but do not downgrade
        notify   => Exec['dockerhost_apt_get_update'],
      }
      package { 'docker-ce-cli' :
        ensure  => $docker_version,
        require => Exec['dockerhost_apt_get_update'],
      }
    } else {
      notice("Docker version ${docker_version} does not have a docker-ce-cli package")
    }
  }

  package { [
    'python3-yaml',  # check_docker_containers requirement
  ] :
    ensure => 'installed',
  }

  $docker_command = $docker_package_name ? {
    'docker-ce' => 'dockerd',  # docker-ce has a new dockerd executable
    default     => undef,
  }

  $daemon_subcommand = $docker_package_name ? {
    'docker-ce' => '',  # docker-ce removed the 'daemon' in '/usr/bin/docker daemon'
    default     => undef,
  }

  # Make it possible to not set a class::docker DNS at all by passing in the empty string
  $_docker_dns = $docker_dns ? {
    ''      => undef,
    default => $docker_dns,
  }

  if $tcp_bind and has_key($::tls_certificates, $::fqdn) and has_key($::tls_certificates[$::fqdn], 'infra_cert') {
    $_tcp_bind = $tcp_bind
    $tls_enable = true
    $tls_cacert = '/etc/ssl/certs/infra.crt'
    $tls_cert   = $::tls_certificates[$::fqdn]['infra_cert']
    $tls_key    = $::tls_certificates[$::fqdn]['infra_key']
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
      manage_package              => false,
      manage_kernel               => false,
      use_upstream_package_source => false,
      extra_parameters            => $_extra_parameters,
      docker_command              => $docker_command,
      daemon_subcommand           => $daemon_subcommand,
      require                     => Package[$docker_package_name],
    }
  } else {
    class {'docker':
      storage_driver              => $storage_driver,
      manage_package              => false,
      manage_kernel               => false,
      use_upstream_package_source => false,
      dns                         => $_docker_dns,
      extra_parameters            => $docker_extra_parameters,
      docker_command              => $docker_command,
      daemon_subcommand           => $daemon_subcommand,
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
    '/usr/bin/docker-compose':
      # workaround: docker_compose won't find the binary in /usr/local/bin :(
      ensure => 'link',
      target => '/usr/local/bin/docker-compose',
      ;
    }

  if $::sunet_has_nrpe_d == 'yes' {
    # variables used in etc_sudoers.d_nrpe_dockerhost_checks.erb / nagios_nrpe_checks.erb
    if $::operatingsystem == 'Ubuntu' and versioncmp($::operatingsystemrelease, '15.04') >= 0 {
      $check_docker_containers_args = '--systemd'
    } else {
      $check_docker_containers_args = '--init_d'
    }

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
      cmd           => '/bin/echo \'Running \"/usr/bin/docker system prune -af\" disabled since it removes too many tags\'',
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

  if $::sunet_nftables_opt_in == 'yes' or ( $::operatingsystem == 'Ubuntu' and versioncmp($::operatingsystemrelease, '22.04') >= 0 ) {
    file {
      '/etc/nftables/conf.d/200-sunet_dockerhost.nft':
        ensure  => file,
        mode    => '0400',
        content => template('sunet/dockerhost/200-dockerhost_nftables.nft.erb'),
        ;
      '/etc/systemd/system/docker.service.d/docker_nftables_ns.conf':
        ensure  => file,
        mode    => '0444',
        content => template('sunet/dockerhost/systemd_dropin_nftables_ns.conf.erb'),
        ;
    }
  }
}
