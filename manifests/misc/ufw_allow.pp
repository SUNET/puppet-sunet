# A simpler and more competent interface to ufw::allow
define sunet::misc::ufw_allow(
  $from,
  $port,
  $to    = 'any',  # both IPv4 and IPv6
  $proto = ['tcp'],
) {
  $_from = flatten([ $from ])
  $_ports = flatten([ $port ])
  $_protocols = flatten([ $proto ])

  each($_from) |$_src| {
    each($_port) |$_ports| {
      each($_proto) |$_protocols| {
        ufw::allow { "_ufw_allow_client_${from}_to_${to}_${port}_${proto}":
          from => $_src,
          ip   => $to,
          port => $_port,
          prot => $_proto,
        }
      }
    }
  }
}
