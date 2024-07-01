# Open host firewall to allow clients to access a service.
define sunet::nftables::allow(
  $from,           # Allow traffic 'from' this IP (or list of IP:s).
  $port,           # Allow traffic to this port (or list of ports).
  $to     = 'any',  # Allow traffic to this IP (or list of IP:s). 'any' means both IPv4 and IPv6.
  $proto  = 'tcp',  # Allow traffic using this protocol (or list of protocols).
  ) {
  ensure_resource('sunet::nftables::ufw_allow_compat', $name, {
    from  => $from,
    to    => $to,
    proto => $proto,
    port  => $port,
  })
}
