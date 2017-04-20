define sunet::bird::peer(
  String $remote_as,
  String $remote_ip,
  String $template
) {
  concat::fragment { "${name}_bgp_peer":
    target   => '/etc/bird/bird.conf',
    order    => '20',
    content  => template("sunet/bird/bgp.erb"),
    notify   => Service[$bird]
  }
}
