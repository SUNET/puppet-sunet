# SUNET frontend BGP Route Reflector config
class sunet::lb::route_reflector(
  String $router_id = $facts['networking']['ip'],
) {
  $config = hiera_hash('sunet_frontend')
  if $config =~ Hash[String, Hash] {
    $ignore_peers_h = $config['route_reflector']['peers'].filter | $peer, $params | {
      has_key($params, 'monitor') and $params['monitor'] == false
    }

    $ignore_peers = join(keys($ignore_peers_h), ' ')
    notice("Peers without monitoring: ${ignore_peers}")
    $check_args = $ignore_peers ? {
      ''      => '',
      default => sprintf('--ignore_peers %s', $ignore_peers)
    }

    class {'sunet::bird':
      router_id  => $router_id,
      check_args => $check_args,
    }

    create_resources('sunet::bird::peer', $config['route_reflector']['peers'])
  } else {
    fail('No/bad SUNET frontend route reflector configuration found in hiera')
  }
}
