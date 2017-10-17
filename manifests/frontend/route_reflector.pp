# SUNET frontend BGP Route Reflector config
class sunet::frontend::route_reflector(
  String $router_id = $ipaddress_default,
) {
  $config = hiera_hash('sunet_frontend')
  if is_hash($config) {
    class {'sunet::bird': router_id => $router_id }

    create_resources('sunet::bird::peer', $config['route_reflector']['peers'])
  } else {
    fail('No SUNET frontend route reflector configuration found in hiera')
  }
}
