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
    sunet::frontend::api { 'frontend_api': }
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
  $ip,
  $check_url,
  $check_match,
) {
  sunet::exabgp::monitor::url { "website_${name}":
    url   => $check_url,
    match => $check_match,
    route => "${ip}/32 next-hop self",
  }
}
