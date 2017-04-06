define sunet::exabgp::config(
  String $peer_address  = undef,
  String $peer_as       = undef,
  String $local_address = undef,
  String $local_as      = undef,
  String $router_id     = $local_address,
  String $monitor       = '/etc/bgp/monitor',
  String $config        = '/etc/bgp/exabgp.conf',
) {
  sunet::misc::ufw_allow { "allow_bgp_peer_${peer_address}":
    from => $peer_address,
    port => '179',
  }

  file { "${config}":
    ensure  => file,
    content => template("sunet/exabgp/exabgp.conf.erb")
  }
}
