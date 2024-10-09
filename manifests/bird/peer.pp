# sunet::bird::peer
define sunet::bird::peer(
  String            $remote_as,
  String            $remote_ip,
  String            $template,
  Optional[String]  $password_hiera_key = undef,
  Optional[Boolean] $monitor = true,  # This is currently a no-op here - used in sunet::lb::route_reflector
) {
  # Hiera hash (deep) merging does not seem to work with one yaml backend and one
  # gpg backend, so we couldn't put the password in secrets.yaml and just merge it in
  $password = $password_hiera_key ? {
    undef   => undef,
    default => lookup($password_hiera_key, undef, undef, undef)
  }

  if is_ipaddr($remote_ip, 4) {
    concat::fragment { "${name}_bgp_peer":
      target  => '/etc/bird/bird.conf',
      order   => '20',
      content => template('sunet/bird/bgp.erb'),
      notify  => Service['bird']
    }
  } elsif is_ipaddr($remote_ip, 6) {
    concat::fragment { "${name}_bgp_peer6":
      target  => '/etc/bird/bird6.conf',
      order   => '20',
      content => template('sunet/bird/bgp.erb'),
      notify  => Service['bird6']
    }
  } else {
    fail("Peer IP address ${remote_ip} is neither IPv4 nor IPv6")
  }
}
