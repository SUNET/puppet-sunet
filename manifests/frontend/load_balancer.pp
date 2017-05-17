# Interface, ExaBGP and haproxy config for a load balancer
class sunet::frontend::load_balancer(
  String $router_id = $ipaddress_default,
  String $basedir = '/opt/frontend',
) {
  $config = hiera_hash('sunet_frontend')
  if is_hash($config) {
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
    configure_websites { 'websites':
      websites => $config['load_balancer']['websites'],
      basedir  => $basedir,
      confdir  => $confdir,
    }
    sunet::exabgp { 'load_balancer':
      docker_volumes => ["${basedir}/haproxy/scripts:${basedir}/haproxy/scripts:ro",
                         ],
    }
    sunet::frontend::haproxy { 'load_balancer':
      basedir          => "${basedir}/haproxy",
      confdir          => $confdir,
      apidir           => $apidir,
      haproxy_image    => $config['load_balancer']['haproxy_image'],
      haproxy_imagetag => $config['load_balancer']['haproxy_imagetag'],
    }
    sunet::frontend::api { 'sunetfrontend':
      basedir => $apidir,
    }
    sysctl_ip_nonlocal_bind { 'load_balancer': }

    # XXX accomplish this with some haproxy config instead
    #sunet::docker_run {'alwayshttps':
    #  image    => 'docker.sunet.se/always-https',
    #  ports    => ['80:80'],
    #  env      => ['ACME_URL=http://acme-c.sunet.se']
    #}
    sunet::misc::ufw_allow { "always-https-allow-http":
      from => 'any',
      port => '80'
    }
  } else {
    fail('No SUNET frontend load balancer config found in hiera')
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
    local_ip  => $::ipaddress_default,
  }
  create_resources('load_balancer_peer', $peers, $defaults)
}

define load_balancer_peer(
  String           $as,
  Optional[String] $local_ip,
  String           $remote_ip,
  Optional[String] $router_id,
) {
  sunet::exabgp::neighbor { "peer_${name}":
    local_as       => $as,
    local_address  => $local_ip,
    peer_as        => $as,
    peer_address   => $remote_ip,
    router_id      => $router_id,
  }
}

define configure_websites($websites, $basedir, $confdir)
{
  create_resources('load_balancer_website', $websites, {
    'basedir' => $basedir,
    'confdir' => $confdir,
    })
}

define load_balancer_website(
  Array            $frontends,
  Hash             $backends,
  String           $basedir,
  String           $confdir,
  Optional[String] $frontend_template = undef,
  Hash             $frontend_template_params = {},
  Array            $allow_ports = [],
  Optional[String] $letsencrypt_server = undef,
) {
  $_ipv4 = map($frontends) |$fe| {
    $fe['primary_ips'].filter |$ip| { is_ipaddr($ip, 4) }
  }
  $_ipv6 = map($frontends) |$fe| {
    $fe['primary_ips'].filter |$ip| { is_ipaddr($ip, 6) }
  }
  # avoid lists in list
  $ipv4 = flatten($_ipv4)
  $ipv6 = flatten($_ipv6)

  # There doesn't seem to be a function to just get the index of an
  # element in an array in Puppet, so we iterate over all the elements in
  # $frontends until we find our fqdn
  each($frontends) |$index, $fe| {
    if $fe['fqdn'] == $::fqdn {
      sunet::exabgp::monitor::haproxy { $name:
        ipv4  => $ipv4,
        ipv6  => $ipv6,
        index => $index + 1,
      }
    } else {
      $fe_fqdn = $fe['fqdn']
      debug("No match on frontend name $fe_fqdn (my fqdn $::fqdn)")
    }
  }

  # Create backend directory for this website so that the sunetfrontend-api will
  # accept register requests from the servers
  file {
    "${basedir}/api/backends/${name}":
      ensure => 'directory',
      group  => 'sunetfrontend',
      mode   => '0770',
      ;
  }

  # Allow the backend servers for this website to access the sunetfrontend-api
  # to register themselves.
  $backend_ips = keys($backends)
  sunet::misc::ufw_allow { "allow_backends_to_api_${name}":
    from => $backend_ips,
    port => '8080',  # port of the sunetfronted-api
  }

  # 'export' config to a file usable by haproxy-config-update+haproxy-backend-config
  # to create backend configuration
  $export_data = {'backends' => $backends}
  file { "${confdir}/${name}_backends.yml":
    ensure  => 'file',
    group   => 'sunetfrontend',
    mode    => '0640',
    content => inline_template("<%= @export_data.to_yaml %>\n"),
  }

  if $frontend_template != undef {
    $server_name = $name
    $params = $frontend_template_params
    # Note that haproxy actually does _not_ want IPv6 addresses to be enclosed by brackets.
    $ips = $ipv4 + $ipv6
    concat::fragment { "${name}_haproxy_frontend":
      target   => "${basedir}/haproxy/etc/haproxy-frontends.cfg",
      order    => '20',
      content  => template($frontend_template),
    }
  }

  # Add the IP addresses to the list of addresses that will get added to the loopback
  # interface before haproxy starts
  $ip_addr_add = ["# website ${name}",
                  map($ipv4 + $ipv6) | $ip | { "ip addr add ${ip} dev lo" },
                  "\n",
                  ]
  concat::fragment { "${name}_haproxy-pre-start_${name}":
    target   => "${basedir}/haproxy/scripts/haproxy-pre-start.sh",
    order    => '20',
    content  => $ip_addr_add.join("\n"),
  }

  if $allow_ports != [] {
    sunet::misc::ufw_allow { "load_balancer_${name}_allow_ports":
      from => 'any',
      to   => [$ipv4, $ipv6],
      port => $allow_ports,
    }
  }

  if $letsencrypt_server != undef {
    sunet::dehydrated::client_define { $name :
      domain => $name,
      server => $letsencrypt_server,
    }
  }
}
