# Interface, ExaBGP and haproxy config for a load balancer
#
# Two versions of the websites setup are supported, but they won't work simultaneously!
#
class sunet::lb::load_balancer(
  String  $router_id   = $ipaddress_default,
  String  $basedir     = '/opt/frontend',
  Integer $base_uidgid = lookup('sunet_frontend_load_balancer_base_uidgid', undef, undef, 800),
  String  $interface   = 'eth0',
  Integer $frontend    = $base_uidgid + 0,
  Integer $fe_api      = $base_uidgid + 1,
  Integer $fe_monitor  = $base_uidgid + 2,
  Integer $fe_config   = $base_uidgid + 3,
  Integer $haproxy     = $base_uidgid + 10,
  Integer $telegraf    = $base_uidgid + 11,
  Integer $varnish     = $base_uidgid + 12,
) {
  # Set up users for running all services as non-root
  class { 'sunet::lb::load_balancer::users':
    frontend   => $frontend,
    fe_api     => $fe_api,
    fe_monitor => $fe_monitor,
    fe_config  => $fe_config,
    haproxy    => $haproxy,
    telegraf   => $telegraf,
    varnish    => $varnish,
  }

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
      $websites = $config['load_balancer']['websites']

      sunet::lb::load_balancer::configure_websites { 'websites':
        interface => $interface,
        websites  => $websites,
        basedir   => $basedir,
        confdir   => $confdir,
        scriptdir => $scriptdir,
      }
    } elsif has_key($config['load_balancer'], 'websites2') {
      # name used during migration
      $websites = $config['load_balancer']['websites2']
      sunet::lb::load_balancer::configure_websites2 { 'websites':
        interface => $interface,
        websites  => $websites,
        basedir   => $basedir,
        confdir   => $confdir,
        scriptdir => $scriptdir,
      }
    } else {
      fail('Load balancer config contains neither "websites" nor "websites2"')
    }

    class { 'sunet::lb::load_balancer::services':
      interface => $interface,
      router_id => $router_id,
      basedir   => $basedir,
      config    => $config,
    }
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
}
