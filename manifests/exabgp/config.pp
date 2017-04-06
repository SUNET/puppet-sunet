define sunet::exabgp::config(
  String           $peer_address,
  String           $peer_as,
  String           $local_address,
  String           $local_as,
  Optional[String] $router_id     = undef,
  String           $monitor       = '/etc/bgp/monitor',
  String           $config        = '/etc/bgp/exabgp.conf',
) {
  sunet::misc::ufw_allow { "allow_bgp_peer_${peer_address}":
    from => $peer_address,
    port => '179',
  }

  $router_id_config = pick($router_id, $local_address)

  file { "${config}":
    ensure  => file,
    content => template("sunet/exabgp/exabgp.conf.erb")
  }
}
