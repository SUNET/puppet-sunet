# Register an HTTPS route on the Invent receiver's Caddy instance.
define sunet::invent::receiver::vhost (
  String[1] $backend,
  Integer[1, 65535] $port,
) {
  concat::fragment { "invent-caddy-vhost-${title}":
    target  => '/opt/caddy/conf/Caddyfile',
    order   => '10',
    content => template('sunet/invent/receiver/vhost.erb'),
  }
}
