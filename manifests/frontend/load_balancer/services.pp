# setup the common services on a Sunet frontend host (exabgp, api, telegraf etc.)
class sunet::frontend::load_balancer::services(
  String $router_id,
  String $basedir,
  Hash[String, Hash] $config,
  Integer $api_port = 8080,
  Integer $statsd_port = 8125,
) {
  #
  # Exabgp, runs as a service - not in Docker (because it needs to run in the hosts network namespace)
  #
  sunet::exabgp::package { 'exabgp': }

  sunet::exabgp::config { 'exabgp_config':
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
      content => template('sunet/frontend/websites_monitor.py.erb'),
      notify  => Service['exabgp'],
    ;
  }

  configure_peers { 'peers': router_id => $router_id, peers => $config['load_balancer']['peers'] }

  sunet::exabgp::molly_guard { $name :
    service_name => 'exabgp',
  }

  #
  # Sunet Frontend API (where backends register their availability)
  #
  $apidir = "${basedir}/api"

  sunet::frontend::api::server { 'sunetfrontend':
    basedir    => $apidir,
    docker_run => false,
    api_port   => $api_port,
    #docker_tag => pick($config['load_balancer']['api_imagetag'], 'latest'),
  }
  if $::facts['sunet_nftables_enabled'] == 'yes' {
    sunet::nftables::docker_expose { 'frontend-api' :
      allow_clients => get_all_backend_ips($config),
      port          => $api_port,
    }
  }

  #
  # Telegraf
  #
  sunet::frontend::telegraf { 'frontend_telegraf':
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
  $api_image = get_config($config, 'api_image', 'docker.sunet.se/sunetfrontend-api')
  $api_imagetag = get_config($config, 'api_imagetag', 'latest')
  $api_basedir = "${basedir}/api"
  #
  $exabgp_image = get_config($config, 'exabgp_image', 'docker.sunet.se/sunet/docker-sunet-exabgp')
  $exabgp_imagetag = get_config($config, 'exabgp_imagetag', 'latest')
  $exabgp_volumes = [
    "${basedir}/haproxy/scripts:${basedir}/haproxy/scripts:ro",
    "${monitor_dir}:${monitor_dir}:ro",
  ]
  #
  $telegraf_image = get_config($config, 'telegraf_image', 'docker.sunet.se/eduid/telegraf')
  $telegraf_imagetag = get_config($config, 'telegraf_imagetag', 'stable')
  $telegraf_basedir = "${basedir}/telegraf"
  $telegraf_volumes = get_config($config, 'telegraf_volumes', [])
  #
  sunet::docker_compose {'frontend_compose':
    service_name => 'frontend',
    description  => 'Sunet frontend load_balancer services',
    compose_dir  => '/opt/frontend/config',
    content      => template('sunet/frontend/docker-compose_frontend.yml.erb'),
  }

}

# Create resources for Exabgp peers
define configure_peers($router_id, $peers)
{
  $defaults = {
    router_id => $router_id,
  }
  create_resources('sunet::frontend::load_balancer::peer', $peers, $defaults)
}

# Convenience function to load a value from the load_balancer section of the config
function get_config(
  Hash[String, Hash] $config,
  String $name,
  $default = undef
) {
  has_key($config['load_balancer'], $name) ? {
    true  => $config['load_balancer'][$name],
    false => $default,
  }
}

# Get a list of all the instances backends - they should all be able to contact the API
function get_all_backend_ips(
  Hash[String, Hash] $config,
) >> Array[String] {
  if has_key($config['load_balancer'], 'websites') {
    $websites = $config['load_balancer']['websites']
  } elsif has_key($config['load_balancer'], 'websites2') {
    # name used during migration
    $websites = $config['load_balancer']['websites2']
  } else {
    fail('Load balancer config contains neither "websites" nor "websites2"')
  }

  $all_ips = map($websites) | $instance_name, $v1 | {
    if 'backends' in $v1 {
      map($v1['backends']) | $backend_name, $v2 | {
        map($v2) | $backend_fqdn, $v3 | {
          'ips' in $v3 ? {
            true => $v3['ips'],
            false => []
          }
        }
      }
    }
  }

  $uniq = flatten($all_ips).unique
  $uniq
}
