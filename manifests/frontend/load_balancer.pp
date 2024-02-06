# Interface, ExaBGP and haproxy config for a load balancer
#
# Two versions of the websites setup are supported, but they won't work simultaneously!
#
class sunet::frontend::load_balancer(
  String  $router_id   = $ipaddress_default,
  String  $basedir     = '/opt/frontend',
  Integer $base_uidgid = lookup('sunet_frontend_load_balancer_base_uidgid', Integer, undef, 800),
  Integer $frontend    = $base_uidgid + 0,
  Integer $fe_api      = $base_uidgid + 1,
  Integer $fe_monitor  = $base_uidgid + 2,
  Integer $fe_config   = $base_uidgid + 3,
  Integer $haproxy     = $base_uidgid + 10,
  Integer $telegraf    = $base_uidgid + 11,
  Integer $varnish     = $base_uidgid + 12,
) {
  $config = lookup('sunet_frontend', undef, undef, undef)
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

      sunet::frontend::load_balancer::configure_peers { 'peers': router_id => $router_id, peers => $config['load_balancer']['peers'] }

      sunet::frontend::load_balancer::configure_websites2 { 'websites':
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
      statsd_listen_address => pick($::ipaddress_docker0, 'no-address-provided'),
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

