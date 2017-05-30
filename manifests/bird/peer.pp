define sunet::bird::peer(
  String           $remote_as,
  String           $remote_ip,
  String           $template,
  Optional[String] $password = undef,
) {
  if is_ipaddr($remote_ip, 4) {
    concat::fragment { "${name}_bgp_peer":
      target   => '/etc/bird/bird.conf',
      order    => '20',
      content  => template("sunet/bird/bgp.erb"),
      notify   => Service[$bird]
    }
  } elsif is_ipaddr($remote_ip, 6) {
    concat::fragment { "${name}_bgp_peer6":
      target   => '/etc/bird/bird6.conf',
      order    => '20',
      content  => template("sunet/bird/bgp.erb"),
      notify   => Service[$bird6]
    }
  } else {
    fail("Peer IP address $remote_ip is neither IPv4 nor IPv6")
  }
}
