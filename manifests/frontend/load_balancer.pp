# Interface, ExaBGP and haproxy config for a load balancer
#
# Two versions of the websites setup are supported, but they won't work simultaneously!
#
class sunet::frontend::load_balancer(
  String $router_id = $ipaddress_default,
  String $basedir   = '/opt/frontend',
) {
  $config = hiera_hash('sunet_frontend')
  if $config =~ Hash[String, Hash] {
    $confdir = "${basedir}/config"
    $scriptdir = "${basedir}/scripts"
    $apidir = "${basedir}/api"

    ensure_resource('sunet::misc::create_dir', ['/etc/bgp', $confdir, $scriptdir],
                    { owner => 'root', group => 'root', mode => '0755' })

    if has_key($config['load_balancer'], 'websites') and has_key($config['load_balancer'], 'websites2') {
      fail("Can't configure websites and websites2 at the same time unfortunately")
    }

    if has_key($config['load_balancer'], 'websites') {
      #
      # Old style config
      #
      fail("Migrate your frontend config from 'websites' to 'websites2'")
    }
    if has_key($config['load_balancer'], 'websites2') {
      #
      # New style config
      #
      sunet::exabgp::config { 'exabgp_config': }
      file { '/etc/bgp/monitor':
        ensure  => file,
        mode    => '0755',
        content => template('sunet/frontend/websites2_monitor.py.erb'),
        notify  => Sunet::Exabgp['load_balancer'],
      }

      configure_peers { 'peers': router_id => $router_id, peers => $config['load_balancer']['peers'] }

      configure_websites2 { 'websites':
        websites  => $config['load_balancer']['websites2'],
        basedir   => $basedir,
        confdir   => $confdir,
        scriptdir => $scriptdir,
      }
    }

    $exabgp_imagetag = has_key($config['load_balancer'], 'exabgp_imagetag') ? {
      true  => $config['load_balancer']['exabgp_imagetag'],
      false => 'latest',
    }
    sunet::exabgp { 'load_balancer':
      docker_volumes => ["${basedir}/haproxy/scripts:${basedir}/haproxy/scripts:ro",
                         '/opt/frontend/monitor:/opt/frontend/monitor:ro',
                         '/dev/log:/dev/log',
                         ],
      version        => $exabgp_imagetag,
    }

    sunet::frontend::api::server { 'sunetfrontend':
      basedir    => $apidir,
      docker_tag => pick($config['load_balancer']['api_imagetag'], 'latest'),
    }

    sunet::frontend::telegraf { 'frontend_telegraf':
      docker_image          => pick($config['load_balancer']['telegraf_image'], 'docker.sunet.se/eduid/telegraf'),
      docker_imagetag       => pick($config['load_balancer']['telegraf_imagetag'], 'stable'),
      docker_volumes        => pick($config['load_balancer']['telegraf_volumes'], []),
      forward_url           => $config['load_balancer']['telegraf_forward_url'],
      statsd_listen_address => pick($::ipaddress_docker0, ''),
    }

    sunet::misc::ufw_allow { 'always-https-allow-http':
      from => 'any',
      port => '80'
    }

    # Create snakeoil bundle as fallback certificate for haproxy
    $snakeoil_key = '/etc/ssl/private/ssl-cert-snakeoil.key'
    $snakeoil_cert = '/etc/ssl/certs/ssl-cert-snakeoil.pem'
    $snakeoil_bundle = '/etc/ssl/snakeoil_bundle.crt'
    sunet::misc::certbundle { 'snakeoil_bundle':
      bundle => ["cert=${snakeoil_cert}",
                 "key=${snakeoil_key}",
                 "out=${snakeoil_bundle}",
                 ],
      group  => 'ssl-cert',
    }
  } else {
    fail('No/bad SUNET frontend load balancer config found in hiera')
  }
}

define sysctl_ip_nonlocal_bind() {
  # Allow haproxy to bind() to a service IP address even if it haven't actually
  # been set up on an interface yet
  augeas { 'frontend_ip_nonlocal_bind_config':
    context => '/files/etc/sysctl.d/10-sunet-frontend-ip-non-local-bind.conf',
    changes => [
                'set net.ipv4.ip_nonlocal_bind 1',
                'set net.ipv6.ip_nonlocal_bind 1',
                ],
    notify  => Exec['reload_sysctl_10-sunet-frontend-ip-non-local-bind.conf'],
  }

  exec { 'reload_sysctl_10-sunet-frontend-ip-non-local-bind.conf':
    command     => '/sbin/sysctl -p /etc/sysctl.d/10-sunet-frontend-ip-non-local-bind.conf',
    refreshonly => true,
  }
}

define configure_peers($router_id, $peers)
{
  $defaults = {
    router_id => $router_id,
  }
  create_resources('sunet::frontend::load_balancer::peer', $peers, $defaults)
}

define configure_websites($websites, $basedir, $confdir)
{
  create_resources('sunet::frontend::load_balancer::website', $websites, {
    'basedir' => $basedir,
    'confdir' => $confdir,
    })
}

define configure_websites2($websites, $basedir, $confdir, $scriptdir)
{
  each($websites) | $site, $config | {
    create_resources('sunet::frontend::load_balancer::website2', {$site => {}}, {
      'basedir'   => $basedir,
      'confdir'   => $confdir,
      'scriptdir' => $scriptdir,
      'config'    => $config,
      })
  }
}
