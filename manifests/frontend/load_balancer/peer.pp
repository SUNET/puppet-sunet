# peer
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
      $_local_ip_family = 4
      $_local_ip_fact = 'ipaddress_default'
    } elsif is_ipaddr($remote_ip, 6) {
      $_local_ip = $::ipaddress6_default
      $_local_ip_family = 6
      $_local_ip_fact = 'ipaddress6_default'
    }
    # Ubuntu hosts (ca 2017-2018, running 16.04) frequently loose their IPv6 default route,
    # which leads to the ipaddress6_default fact being undef. Go through some trouble to
    # give a clear error message in that case.
    if ($_local_ip == undef) {
      fail("Could not figure out local IPv${_local_ip_family} address using the fact \$::${_local_ip_fact}, got: '${_local_ip}'")
    }
  } else {
    $_local_ip = $local_ip
  }

  # Hiera hash (deep) merging does not seem to work with one yaml backend and one
  # gpg backend, so we couldn't put the password in secrets.yaml and just merge it in
  $md5 = $password_hiera_key ? {
    undef   => undef,
    default => lookup($password_hiera_key, undef, undef, undef)
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
