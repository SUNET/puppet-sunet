# Interface, ExaBGP and haproxy config for a load balancer
class sunet::frontend::load_balancer(
  String $router_id            = $ipaddress_default,
  String $hiera_peer_config    = 'frontend_load_balancer_peers',
  String $hiera_website_config = 'frontend_load_balancer_websites',
) {
  file {
    '/etc/bgp':
      ensure => 'directory',
      ;
  }

  configure_peers { 'peers': router_id => $router_id, peers => hiera_hash($hiera_peer_config) } ->
  configure_websites { 'websites': websites => hiera_hash($hiera_website_config) } ->

  sunet::exabgp { 'load_balancer': }
}

define configure_peers($router_id, $peers)
{
  if is_hash($peers) {
    $defaults = {
      local_ip => $::ipaddress_default,
    }
    create_resources('load_balancer_peer', $peers, $defaults)
  } else {
    fail('No load balancer peers found in hiera')
  }
}

define load_balancer_peer(
  $as,
  $local_ip,
  $remote_ip,
) {
  sunet::exabgp::config { "peer_${name}":
    local_as       => $as,
    local_address  => $local_ip,
    peer_as        => $as,
    peer_address   => $remote_ip,
  }
}

define configure_websites($websites)
{
  if is_hash($websites) {
    create_resources('load_balancer_website', $websites)
  } else {
    warning('No load balancer websites found in hiera')
  }
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
