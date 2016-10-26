# Open host firewall to allow clients to access a service.
define sunet::misc::ufw_allow(
  $from,           # Allow traffic 'from' this IP (or list of IP:s).
  $port,           # Allow traffic to this port (or list of ports).
  $to    = 'any',  # Allow traffic to this IP (or list of IP:s). 'any' means both IPv4 and IPv6.
  $proto = 'tcp',  # Allow traffic using this protocol (or list of protocols).
  ) {

  $_clients = flatten([ $clients_list ])

  # if $to is '', turn it into 'any'.
  # ufw module behaviour of changing '' to $ipaddress_eth0 or $ipaddress does not make much sense.
  $_to = $to ? {
    ''      => 'any',
    default => $to,
  }

  each(flatten([$from])) |$_from| {
    if ! $_from.is_ipaddress {
      fail("'from' is not an IP address: ${_from}");
    }
    each(flatten([$to])) |$_to| {
      if $_to != 'any' and ! $_to.is_ipaddress {
        fail("'to' is not an IP address: ${_from}");
      }
      each(flatten([$port])) |$_port| {
        each(flatten([$proto])) |$_proto| {
          ensure_resource('ufw::allow', "_ufw_allow__from_${_from}__to_${_to}__${_port}/${_proto}", {
            from  => $_from,
            ip    => $_to,
            proto => $_proto,
            port  => sprintf("%s", $_port),
            })
        }
      }
    }
  }
}
