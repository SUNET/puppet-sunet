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
    $apidir = "${basedir}/api"

    ensure_resource('sunet::misc::create_dir', ['/etc/bgp', $confdir], { owner => 'root', group => 'root', mode => '0755' })

    if has_key($config['load_balancer'], 'websites') and has_key($config['load_balancer'], 'websites2') {
      fail("Can't configure websites and websites2 at the same time unfortunately")
    }

    if has_key($config['load_balancer'], 'websites') {
      #
      # Old style config
      #
      sunet::exabgp::config { 'exabgp_config': }
      configure_peers { 'peers': router_id => $router_id, peers => $config['load_balancer']['peers'] }

      sunet::frontend::haproxy { 'load-balancer':
        basedir               => "${basedir}/haproxy",
        confdir               => $confdir,
        apidir                => $apidir,
        haproxy_image         => $config['load_balancer']['haproxy_image'],
        haproxy_imagetag      => $config['load_balancer']['haproxy_imagetag'],
        port80_acme_c_backend => $config['load_balancer']['port80_acme_c_backend'],
        static_backends       => $config['load_balancer']['static_backends'],
      }

      configure_websites { 'websites':
        websites => $config['load_balancer']['websites'],
        basedir  => $basedir,
        confdir  => $confdir,
      }

      concat::fragment { "${name}_haproxy-pre-start_end":
        target  => "${basedir}/haproxy/scripts/haproxy-pre-start.sh",
        order   => '99',
        content => "exit 0\n",
      }

      sysctl_ip_nonlocal_bind { 'load_balancer': }
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
        websites => $config['load_balancer']['websites2'],
        basedir  => $basedir,
        confdir  => $confdir,
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

    sunet::frontend::api { 'sunetfrontend':
      basedir    => $apidir,
      docker_tag => pick($config['load_balancer']['api_imagetag'], 'latest'),
    }

    sunet::frontend::statsd { 'frontend_statsd':
      docker_image    => pick($config['statsd_image'], 'docker.sunet.se/eduid/statsd'),
      docker_imagetag => pick($config['statsd_imagetag'], 'stable'),
      repeat_host     => pick($config['statsd_repeat_host'], ''),
      repeat_port     => pick($config['statsd_repeat_port'], ''),
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

define configure_websites2($websites, $basedir, $confdir)
{
  each($websites) | $site, $config | {
    create_resources('sunet::frontend::load_balancer::website2', {$site => {}}, {
      'basedir' => $basedir,
      'confdir' => $confdir,
      'config'  => $config,
      })
  }
}
