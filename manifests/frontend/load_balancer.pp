# Interface, ExaBGP and haproxy config for a load balancer
class sunet::frontend::load_balancer(
  String $router_id = $ipaddress_default,
  String $basedir   = '/opt/frontend',
) {
  $config = hiera_hash('sunet_frontend')
  if $config =~ Hash[String, Hash] {
    $confdir = "${basedir}/config"
    $apidir = "${basedir}/api"

    exec { 'load_balancer_mkdir':
      command => "/bin/mkdir -p ${basedir}",
      unless  => "/usr/bin/test -d ${basedir}",
    } ->
    file {
      '/etc/bgp':
        ensure => 'directory',
        ;
      $confdir:
        ensure => 'directory',
        ;
    }

    sunet::exabgp::config { 'exabgp_config': }
    configure_peers { 'peers': router_id => $router_id, peers => $config['load_balancer']['peers'] }
    if has_key($config['load_balancer'], 'websites_old') {
      configure_websites_old { 'websites_old':
        websites => $config['load_balancer']['websites_old'],
        basedir  => $basedir,
        confdir  => $confdir,
      }
    }
    if has_key($config['load_balancer'], 'websites') {
      configure_websites { 'websites':
        websites => $config['load_balancer']['websites'],
        basedir  => $basedir,
        confdir  => $confdir,
      }
    }
    concat::fragment { "${name}_haproxy-pre-start_end":
      target   => "${basedir}/haproxy/scripts/haproxy-pre-start.sh",
      order    => '99',
      content  => "exit 0\n",
    }

    $exabgp_imagetag = has_key($config['load_balancer'], 'exabgp_imagetag') ? {
      true  => $config['load_balancer']['exabgp_imagetag'],
      false => 'latest',
    }
    sunet::exabgp { 'load_balancer':
      docker_volumes => ["${basedir}/haproxy/scripts:${basedir}/haproxy/scripts:ro",
                         "/dev/log:/dev/log",
                         ],
      version        => $exabgp_imagetag,
    }
    sunet::frontend::haproxy { 'load-balancer':
      basedir               => "${basedir}/haproxy",
      confdir               => $confdir,
      apidir                => $apidir,
      haproxy_image         => $config['load_balancer']['haproxy_image'],
      haproxy_imagetag      => $config['load_balancer']['haproxy_imagetag'],
      port80_acme_c_backend => $config['load_balancer']['port80_acme_c_backend'],
      static_backends       => $config['load_balancer']['static_backends'],
    }
    $api_imagetag = has_key($config['load_balancer'], 'api_imagetag') ? {
      true  => $config['load_balancer']['api_imagetag'],
      false => 'latest',
    }
    sunet::frontend::api { 'sunetfrontend':
      basedir    => $apidir,
      docker_tag => $api_imagetag,
    }
    sysctl_ip_nonlocal_bind { 'load_balancer': }

    sunet::misc::ufw_allow { "always-https-allow-http":
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
      group  => 'haproxy',
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
    notify => Exec['reload_sysctl_10-sunet-frontend-ip-non-local-bind.conf'],
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

define configure_websites_old($websites, $basedir, $confdir)
{
  create_resources('sunet::frontend::load_balancer::website_old', $websites, {
    'basedir' => $basedir,
    'confdir' => $confdir,
    })
}

define configure_websites($websites, $basedir, $confdir)
{
  each($websites) | $site, $config | {
    create_resources('sunet::frontend::load_balancer::website', $site, {
      'basedir' => $basedir,
      'confdir' => $confdir,
      'config' => $config,
      })
  }
}
