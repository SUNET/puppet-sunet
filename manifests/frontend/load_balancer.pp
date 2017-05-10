# Interface, ExaBGP and haproxy config for a load balancer
class sunet::frontend::load_balancer(
  String $router_id = $ipaddress_default,
) {
  $config = hiera_hash('sunet_frontend')
  if is_hash($config) {
    file {
      '/etc/bgp':
        ensure => 'directory',
        ;
      '/opt/frontend/haproxy/templates':
        ensure => 'directory',
        ;
    }

    sunet::exabgp::config { 'exabgp_config': }
    configure_peers { 'peers': router_id => $router_id, peers => $config['load_balancer']['peers'] }
    configure_websites { 'websites': websites => $config['load_balancer']['websites'] }
    sunet::exabgp { 'load_balancer':
      docker_volumes => ['/opt/frontend/haproxy/scripts:/opt/frontend/haproxy/scripts:ro',
                         ],
    }
    sunet::frontend::haproxy { 'load_balancer': }
    sunet::frontend::api { 'sunetfrontend': }
    sysctl_ip_nonlocal_bind { 'load_balancer': }

    # XXX accomplish this with some haproxy config instead
    sunet::docker_run {'alwayshttps':
      image    => 'docker.sunet.se/always-https',
      ports    => ['80:80'],
      env      => ['ACME_URL=http://acme-c.sunet.se']
    }
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
  #
  # XXX This setting _might_ actually mean that we don't have to add the
  # IP addresses to any interface at all. Should test that.
  augeas { 'frontend_ip_nonlocal_bind_config':
    context => '/files/etc/sysctl.d/10-sunet-frontend-ip-non-local-bind.conf',
    changes => [
                'set net.ipv4.ip_nonlocal_bind 1',
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
    local_ip => $::ipaddress_default,
  }
  create_resources('load_balancer_peer', $peers, $defaults)
}

define load_balancer_peer(
  $as,
  $local_ip,
  $remote_ip,
) {
  sunet::exabgp::neighbor { "peer_${name}":
    local_as       => $as,
    local_address  => $local_ip,
    peer_as        => $as,
    peer_address   => $remote_ip,
  }
}

define configure_websites($websites)
{
  create_resources('load_balancer_website', $websites)
}

define load_balancer_website(
  Array            $frontends,
  Hash             $backends,
  Optional[String] $frontend_template = undef,
  Hash             $frontend_template_params = {},
  Array            $allow_ports = [],
  Optional[String] $letsencrypt_server = undef,
) {
  $ipv4 = map($frontends) |$fe| {
    $fe['primary_ips'].filter |$ip| { is_ipaddr($ip, 4) }
  }
  $ipv6 = map($frontends) |$fe| {
    $fe['primary_ips'].filter |$ip| { is_ipaddr($ip, 6) }
  }

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
    "/opt/frontend/api/backends/${name}":
      ensure => 'directory',
      group  => 'sunetfrontend',
      mode   => '0770',
      ;
  }

  # Make template files with the haproxy config per backend, so that the
  # haproxy-config-update script can make a haproxy-backends.cfg file
  # containing all backends that have registered with the sunetfrontend-api
  file {
    "/opt/frontend/haproxy/templates/${name}":
      ensure => 'directory',
      ;
  }
#  each($backends) |$backend_ip| {
#    file {
#      "/opt/frontend/haproxy/templates/${name}/${backend_ip}.cfg":
#        ensure  => 'file',
#        content => $backends.to_yaml,
#        ;
#    }
#  }

  # Allow the backend servers for this website to access the sunetfrontend-api
  # to register themselves.
  $backend_ips = keys($backends)
  sunet::misc::ufw_allow { "allow_servers_${name}":
    from => $backend_ips,
    port => '8080',  # port of the sunetfronted-api
  }

  if $frontend_template != undef {
    $server_name = $name
    $params = $frontend_template_params
    $ips = flatten($ipv4 + enclose_ipv6($ipv6))
    concat::fragment { "${name}_haproxy_frontend":
      target   => '/opt/frontend/haproxy/etc/haproxy-frontends.cfg',  # XXX not nice with hard coded path here
      order    => '20',
      content  => template($frontend_template),
    }
  }

  if $allow_ports != [] {
    sunet::misc::ufw_allow { "load_balancer_${name}_allow_ports":
      from => 'any',
      to   => [$ipv4, $ipv6],  # not $ips, ufw does not like brackets around v6 addresses
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
