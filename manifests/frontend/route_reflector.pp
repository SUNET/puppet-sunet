# SUNET frontend BGP Route Reflector config
class sunet::frontend::route_reflector(
  String $router_id         = $ipaddress_default,
  String $hiera_peer_config = 'frontend_route_reflector_peers',
) {
  class {'sunet::bird': router_id => $router_id }

  $peers = hiera_hash($hiera_peer_config)
  if is_hash($peers) {
    create_resources('sunet::bird::peer', $peers)
  } else {
    fail('No route reflector peers found in hiera')
  }
}
