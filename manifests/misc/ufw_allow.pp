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
    each($_ports) |$_port| {
      each($_protocols) |$_proto| {
        ufw::allow { "_ufw_allow_client_${_src}_to_${to}_${_port}_${_proto}":
          from => $_src,
          ip   => $to,
          port => $_port,
          prot => $_proto,
        }
      }
    }
  }
}
