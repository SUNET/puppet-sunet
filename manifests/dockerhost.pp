# Install docker from https://get.docker.com/ubuntu
class sunet::dockerhost(
  String $docker_version                      = 'installed',
  String $docker_package_name                 = 'docker-ce',  # facilitate transition to new docker-ce package
  Enum['stable', 'edge', 'test'] $docker_repo = 'stable',
  $storage_driver                             = undef,
  $docker_extra_parameters                    = undef,
  Boolean $run_docker_cleanup                 = true,
  Optional[Variant[String, Boolean]] $docker_network = lookup('dockerhost_docker_network', Optional[Variant[String, Boolean]], undef, '172.18.0.0/22'),
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

  include sunet::packages::jq # restart_unhealthy_containers requirement
  include sunet::packages::python3_yaml # check_docker_containers requirement
  include stdlib

  # Clean up files created by old garethr-docker-based configuration
  file { '/etc/default/docker':
    ensure => absent,
  }

  file { '/etc/systemd/system/docker.service.d':
    ensure => directory,
    before => Package[$docker_package_name],
  }

  if $::facts['sunet_nftables_enabled'] == 'yes' and $advanced_network == false {
    # The nftables ns dropin file must be in place before the docker service is installed on a new host,
    # otherwise the docker0 interface will be created and interfere until reboot.
    file { '/etc/systemd/system/docker.service.d/docker_nftables_ns.conf':
      ensure  => file,
      mode    => '0444',
      content => template('sunet/dockerhost/systemd_dropin_nftables_ns.conf.erb'),
      require => File['/etc/systemd/system/docker.service.d'],
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

  ensure_resource('sunet::apt::repo_docker', 'sunet-dockerhost-docker-repo', {'docker_repo' => $docker_repo})

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

  # Ubuntu 26.04+ requires write_daemon_config to register the nsrunc runtime.
  if $facts['os']['name'] == 'Ubuntu' and versioncmp($facts['os']['release']['full'], '26.04') >= 0 and ! $write_daemon_config {
    warning('sunet::dockerhost: forcing write_daemon_config=true on Ubuntu 26.04+ (required for nsrunc runtime registration)')
  }
  $_write_daemon_config = $write_daemon_config or
    ($facts['os']['name'] == 'Ubuntu' and versioncmp($facts['os']['release']['full'], '26.04') >= 0)
  $_write_nsrunc = $_write_daemon_config

  # This is an approximation about how to enable IPv6 in Docker, but
  # BEWARE! IPv6 is currently utterly dysfunctional in docker-compose (version 3 / 1.29.2). Sigh.
  #
  $ipv6_parameters = ($enable_ipv6 and ! $_write_daemon_config) ? {
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

  # Wrapper that runs runc inside Docker's mount namespace.
  # systemd 253+ creates a private (slave) mount namespace for Docker when
  # PrivateNetwork=yes is set. Container rootfs overlays are only visible inside
  # that namespace, so runc must enter it to see them.
  if $_write_nsrunc {
    file { '/usr/local/bin/nsrunc':
      ensure  => file,
      mode    => '0755',
      content => template('sunet/dockerhost/nsrunc.erb'),
    }
  }

  if $_write_daemon_config {
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
        notify  => Service['docker'],
        ;
    }
  } else {
    file { '/etc/systemd/system/docker.service.d/sunet-dockerhost.conf':
      ensure  => file,
      mode    => '0444',
      content => template('sunet/dockerhost/service_override.conf.erb'),
      require => File['/etc/systemd/system/docker.service.d'],
      notify  => [Exec['sunet_dockerhost_systemd_reload'], Service['docker']],
    }
    exec { 'sunet_dockerhost_systemd_reload':
      command     => '/bin/systemctl daemon-reload',
      refreshonly => true,
      before      => Service['docker'],
    }
  }

  service { 'docker':
    ensure  => running,
    enable  => true,
    require => $_write_nsrunc ? {
      true  => [Package[$docker_package_name], File['/usr/local/bin/nsrunc']],
      false => Package[$docker_package_name],
    },
  }

  if $docker_network =~ String {
    # Create a useful default network bridge for containers.
    #
    # Docker DNS isn't available on the default 'bridge' interface, so another
    # bridge interface is needed for containers benefiting from the DNS resolution
    # but not running using docker-compose.
    exec { 'create_docker_network':
      command => '/usr/bin/docker network create --driver bridge docker',
      unless  => '/usr/bin/docker network inspect docker',
      require => Service['docker'],
    }
  } elsif $docker_network == true {
    exec { 'create_docker_network':
      command => '/usr/bin/docker network create --driver bridge docker',
      unless  => '/usr/bin/docker network inspect docker',
      require => Service['docker'],
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
    }

  if $facts['os']['name'] == 'Ubuntu' and versioncmp($facts['os']['release']['full'], '26.04') >= 0 {
    package { 'docker-compose-plugin':
      ensure  => installed,
      require => Exec['dockerhost_apt_get_update'],
    }
  } else {
    file { '/usr/local/bin/docker-compose':
      mode    => '0755',
      content => template('sunet/dockerhost/docker-compose.erb'),
    }
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
