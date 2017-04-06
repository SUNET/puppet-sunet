define sunet::exabgp::config(
  String $peer_address  = undef,
  String $peer_as       = undef,
  String $local_address = undef,
  String $local_as      = undef,
  String $router_id     = $local_address,
  String $monitor       = '/etc/bgp/monitor',
  String $config        = '/etc/bgp/exabgp.conf',
) {
  file { "${config}":
    ensure  => file,
    content => template("sunet/exabgp/exabgp.conf.erb")
  }
}
