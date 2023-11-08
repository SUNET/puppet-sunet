# setup the common services on a Sunet frontend host (exabgp, api, telegraf etc.)
class sunet::lb::load_balancer::services(
  String $router_id,
  String $basedir,
  Hash[String, Hash] $config,
  String $interface = 'eth0',
  Integer $api_port = 8080,
  Integer $statsd_port = 8125,
) {
  #
  # Exabgp, runs as a service - not in Docker (because it needs to run in the hosts network namespace)
  #
  sunet::lb::exabgp::package { 'exabgp': }

  sunet::lb::exabgp::config { 'exabgp_config':
    config         => '/etc/exabgp/exabgp.conf',
    monitor        => '/etc/exabgp/monitor',
    notify         => Service['exabgp'],
    exabgp_version => '4',
  }

  # inotify used in websites_monitor.py.erb
  ensure_resource('package', 'python3-pyinotify', {ensure => 'installed'})

  $monitor_dir = "${basedir}/monitor"

  file {
    $monitor_dir:
      ensure  => 'directory',
      ;
    '/etc/exabgp/monitor':
      ensure  => file,
      mode    => '0755',
      content => template('sunet/lb/websites_monitor.py.erb'),
      notify  => Service['exabgp'],
    ;
  }

  sunet::lb::load_balancer::configure_peers { 'peers': router_id => $router_id, peers => $config['load_balancer']['peers'] }

  sunet::lb::exabgp::molly_guard { $name :
    service_name => 'exabgp',
  }

  #
  # Sunet Frontend API (where backends register their availability)
  #
  $apidir = "${basedir}/api"

  sunet::lb::api::server { 'sunetfrontend':
    basedir    => $apidir,
    docker_run => false,
    api_port   => $api_port,
    #docker_tag => pick($config['load_balancer']['api_imagetag'], 'latest'),
  }
  if $::facts['sunet_nftables_enabled'] == 'yes' {
    sunet::nftables::docker_expose { 'frontend-api' :
      allow_clients => sunet::lb::load_balancer::get_all_backend_ips($config),
      port          => $api_port,
      iif          => $interface,
    }
  }

  #
  # Telegraf
  #
  sunet::lb::telegraf { 'frontend_telegraf':
    # docker_image          => pick($config['load_balancer']['telegraf_image'], 'docker.sunet.se/eduid/telegraf'),
    # docker_imagetag       => pick($config['load_balancer']['telegraf_imagetag'], 'stable'),
    # docker_volumes        => pick($config['load_balancer']['telegraf_volumes'], []),
    # statsd_listen_address => pick($::ipaddress_docker0, 'no-address-provided'),
    forward_url        => $config['load_balancer']['telegraf_forward_url'],
    statsd_listen_port => $statsd_port,
    docker_run         => false,
  }


  #
  # Variables used in compose file.
  #   NOTE: For this (scope lookup) to work, this code has to be a class and not a define!
  #
  $api_image = sunet::lb::load_balancer::get_config($config, 'api_image', 'docker.sunet.se/sunetfrontend-api')
  $api_imagetag = sunet::lb::load_balancer::get_config($config, 'api_imagetag', 'latest')
  $api_basedir = "${basedir}/api"
  #
  $exabgp_image = sunet::lb::load_balancer::get_config($config, 'exabgp_image', 'docker.sunet.se/sunet/docker-sunet-exabgp')
  $exabgp_imagetag = sunet::lb::load_balancer::get_config($config, 'exabgp_imagetag', 'latest')
  $exabgp_volumes = [
    "${basedir}/haproxy/scripts:${basedir}/haproxy/scripts:ro",
    "${monitor_dir}:${monitor_dir}:ro",
  ]
  #
  $telegraf_image = sunet::lb::load_balancer::get_config($config, 'telegraf_image', 'docker.sunet.se/eduid/telegraf')
  $telegraf_imagetag = sunet::lb::load_balancer::get_config($config, 'telegraf_imagetag', 'stable')
  $telegraf_basedir = "${basedir}/telegraf"
  $telegraf_volumes = sunet::lb::load_balancer::get_config($config, 'telegraf_volumes', [])
  #
  sunet::docker_compose {'frontend_compose':
    service_name => 'frontend',
    description  => 'Sunet frontend load_balancer services',
    compose_dir  => '/opt/frontend/config',
    content      => template('sunet/lb/docker-compose_frontend.yml.erb'),
  }

}

