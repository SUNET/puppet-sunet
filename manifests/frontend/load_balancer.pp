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
  Array            $ips,
  Array            $frontends,
  Array            $allowed_servers = [],
  Optional[String] $frontend_template = undef,
) {
  # There doesn't seem to be a function to just get the index of an
  # element in an array in Puppet, so we iterate over all the elements in
  # $frontends until we find our fqdn
  each($frontends) |$index, $fe_name| {
    if $fe_name == $::fqdn {
      sunet::exabgp::monitor::haproxy { $name:
        ips   => $ips,
        index => $index + 1,
      }
    } else {
      debug("No match on frontend name $fe_name (my fqdn $::fqdn)")
    }
  }

  # Add the service IP address(es) to the loopback interface so that
  # haproxy can actually receive the requests.
  each($ips) |$ip| {
    exec { "frontend_service_ip_${ip}":
      path => ['/usr/sbin', '/usr/bin', '/sbin', '/bin', ],
      command => "ip addr add ${ip} dev lo",
      unless  => "ip addr show lo | grep -q 'inet.*${ip}'",
    }
  }

  # Create backend directory for this website so that the API will
  # accept register requests from the servers
  file {
    "/opt/frontend/api/backends/${name}":
      ensure => 'directory',
      group  => 'sunetfrontend',
      mode   => '0770',
      ;
  }

  # Allow the backend servers for this website to access the sunetfronted-api
  # to register themselves.
  sunet::misc::ufw_allow { "allow_servers_${name}":
    from => $allowed_servers,
    port => '8080',  # port of the sunetfronted-api
  }

  if $frontend_template != undef {
    concat::fragment { "${name}_haproxy_frontend":
      target   => '/opt/frontend/haproxy/etc/haproxy-frontends.cfg',  # XXX not nice with hard coded path here
      order    => '20',
      content  => template($frontend_template),
    }
  }
}
