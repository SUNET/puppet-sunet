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

    if has_key($config['load_balancer'], 'websites') and has_key($config['load_balancer'], 'websites2') {
      fail("Can't configure websites and websites2 at the same time unfortunately")
    }

    if has_key($config['load_balancer'], 'websites') {
      $websites = $config['load_balancer']['websites']
    } elsif has_key($config['load_balancer'], 'websites2') {
      # name used during migration
      $websites = $config['load_balancer']['websites2']
    } else {
      fail('Load balancer config contains neither "websites" nor "websites2"')
    }

    $confdir = "${basedir}/config"
    $scriptdir = "${basedir}/scripts"

    ensure_resource('sunet::misc::create_dir', [$confdir, $scriptdir],
                    { owner => 'root', group => 'root', mode => '0755' })

    configure_websites { 'websites':
      websites  => $websites,
      basedir   => $basedir,
      confdir   => $confdir,
      scriptdir => $scriptdir,
    }

    class { 'sunet::frontend::load_balancer::services':
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

define configure_websites($websites, $basedir, $confdir, $scriptdir)
{
  each($websites) | $site, $config | {
    create_resources('sunet::frontend::load_balancer::website', {$site => {}}, {
      'basedir'   => $basedir,
      'confdir'   => $confdir,
      'scriptdir' => $scriptdir,
      'config'    => $config,
      })
  }
}
