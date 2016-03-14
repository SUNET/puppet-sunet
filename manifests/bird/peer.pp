define sunet::bird::peer(
  $remote_as  = undef,
  $remote_ip  = undef,
  $template   = undef
) {
  require stdlib
  validate_string($remote_as);
  validate_string($remote_ip);
  validate_string($template);

  concat::fragment { "${name}_bgp_peer":
    target   => '/etc/bird/bird.conf',
    order    => '20',
    content  => template("sunet/bird/bgp.erb"),
    notify   => Service[$bird]
  }
}
