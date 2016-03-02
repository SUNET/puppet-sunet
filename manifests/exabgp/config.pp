define sunet::exabgp::config(
    $peer_address  = undef,
    $peer_as       = undef,
    $local_address = undef,
    $local_as      = undef,
    $router_id     = undef,
    $monitor       = "/etc/bgp/monitor",
    $config        = "/etc/bgp/exabgp.conf"
) {
    require stdlib
    validate_string($peer_address);
    validate_string($peer_as);
    validate_string($local_address);
    validate_string($local_as);
    validate_string($monitor);
    $router_id_config = $router_id ? {
       undef       => $local_address,
       default     => $router_id
    }
    file { "${config}": 
       ensure      => file,
       content     => template("sunet/exabgp/exabgp.conf.erb")
    }
}
