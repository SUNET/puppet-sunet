define sunet::frontend::load_balancer::configure_peers($router_id, $peers)
{
  $defaults = {
    router_id => $router_id,
  }
  $peers.each|$peer| {
    create_resources('sunet::frontend::load_balancer::peer', $peer, $defaults)
  }
}

