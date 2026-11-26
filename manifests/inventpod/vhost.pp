define sunet::inventpod::vhost (
  Pattern[/\A[a-zA-Z0-9.-]+\z/] $backend,
  Integer[1,65535] $port,
) {
  if $title !~ /\A[a-z0-9][a-z0-9.-]*\z/ {
    fail("Invalid HTTPS hostname ${title}")
  }
  $tls = $sunet::inventpod::public_https ? { true => '', false => "  tls internal\n" }
  concat::fragment { "podman2 vhost ${title}":
    target  => '/etc/sunet-podman2/Caddyfile',
    order   => '10',
    content => "${title} {\n${tls}  log\n  reverse_proxy ${backend}:${port} {\n    header_up X-Real-IP {remote_host}\n  }\n}\n",
  }
}
