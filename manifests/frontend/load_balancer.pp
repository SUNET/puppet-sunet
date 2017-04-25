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
    sunet::exabgp { 'load_balancer': }
    sunet::frontend::haproxy { 'load_balancer': }
    sunet::frontend::api { 'sunetfrontend': }
  } else {
    fail('No SUNET frontend load balancer config found in hiera')
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
  $ips,
  $frontends,
  $allowed_servers = [],
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
}
