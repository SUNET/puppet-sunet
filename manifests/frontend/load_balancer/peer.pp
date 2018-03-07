define sunet::frontend::load_balancer::peer(
  String           $as,
  String           $remote_ip,
  Optional[String] $local_ip  = undef,
  Optional[String] $router_id = undef,
  Optional[String] $password_hiera_key = undef,
) {
  # If $local_ip is not set, default to either $::ipaddress_default or $::ipaddress6_default
  # depending on the address family of $remote_ip
  if ! is_ipaddr($local_ip) {
    if is_ipaddr($remote_ip, 4) {
      $_local_ip = $::ipaddress_default
    } elsif is_ipaddr($remote_ip, 6) {
      $_local_ip = $::ipaddress6_default
    }
  } else {
    $_local_ip = $local_ip
  }

  # Hiera hash (deep) merging does not seem to work with one yaml backend and one
  # gpg backend, so we couldn't put the password in secrets.yaml and just merge it in
  $md5 = $password_hiera_key ? {
    undef   => undef,
    default => hiera($password_hiera_key, undef)
  }

  sunet::exabgp::neighbor { "peer_${name}":
    local_as      => $as,
    local_address => $_local_ip,
    peer_as       => $as,
    peer_address  => $remote_ip,
    router_id     => $router_id,
    md5           => $md5,
  }
}

