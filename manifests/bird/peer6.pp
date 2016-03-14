define sunet::bird::peer6(
  $remote_as  = undef,
  $remote_ip  = undef,
  $template   = undef
) {
  require stdlib
  validate_string($remote_as);
  validate_string($remote_ip);
  validate_string($template);

  concat::fragment { "${name}_bgp_peer6":
    target   => '/etc/bird/bird6.conf',
    order    => '20',
    content  => template("sunet/bird/bgp.erb"),
    notify   => Service[$bird6]
  }
}
