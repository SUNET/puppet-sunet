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

  $confdir = "${basedir}/config"
  $scriptdir = "${basedir}/scripts"
  $apidir = "${basedir}/api"

  ensure_resource('sunet::misc::create_dir', ['/etc/bgp', $confdir, $scriptdir],
                  { owner => 'root', group => 'root', mode => '0755' })

  $websites = $config['load_balancer']['websites']

  sunet::lb::load_balancer::configure_websites { 'websites':
    interface => $interface,
    websites  => $websites,
    basedir   => $basedir,
    confdir   => $confdir,
    scriptdir => $scriptdir,
  }

  class { 'sunet::lb::load_balancer::services':
    interface => $interface,
    router_id => $router_id,
    basedir   => $basedir,
    config    => $config,
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
  if has_key($facts['tls_certificates'], $facts['networking']['fqdn']) and has_key($facts['tls_certificates'][$::fqdn], 'infra_cert') {
    $infra_cert = $facts['tls_certificates'][$::fqdn]['infra_cert']
    $infra_key = $facts['tls_certificates'][$::fqdn]['infra_key']

    # Create a haproxy cert bundle from the infracert, to be used as client certififace when connecting to backends
    ensure_resource(sunet::misc::certbundle, "${facts['networking']['fqdn']}_haproxy", {
      bundle => [
        "cert=${infra_cert}",
        "key=${infra_key}",
        'out=private/infra_haproxy.crt',
      ],
    })
  }
}
