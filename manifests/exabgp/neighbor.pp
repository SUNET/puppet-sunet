define sunet::exabgp::neighbor(
  String           $peer_address,
  String           $peer_as,
  String           $local_address,
  String           $local_as,
  Optional[String] $router_id     = undef,
  String           $config        = '/etc/bgp/exabgp.conf',
  String           $md5           = '',
) {
  sunet::misc::ufw_allow { "allow_bgp_peer_${peer_address}":
    from => $peer_address,
    port => '179',
  }

  $router_id_config = pick($router_id, $local_address)

  concat::fragment { "exabgp_neighbor_${peer_address}":
    target  => $config,
    order   => '100',
    content => template('sunet/exabgp/exabgp.conf_neighbor.erb'),
    #notify  => Service['exabgp'],
  }
}
