# SUNET frontend BGP Route Reflector config
class sunet::frontend::route_reflector(
  String $router_id = $::ipaddress_default,
) {
  $config = hiera_hash('sunet_frontend')
  if $config =~ Hash[String, Hash] {
    $ignore_peers = $config['route_reflector']['peers'].filter | $peer, $params | {
      has_key($params, 'monitor') and $params['monitor'] != false
    }

    notify("Peers without monitoring: ${ignore_peers}")

    class {'sunet::bird': router_id => $router_id }

    create_resources('sunet::bird::peer', $config['route_reflector']['peers'])
  } else {
    fail('No/bad SUNET frontend route reflector configuration found in hiera')
  }
}
