include stdlib

define sunet::exabgp(
  Array   $extra_arguments = [],
  String  $config          = '/etc/bgp/exabgp.conf',
  String  $version         = 'latest',
  Integer $port            = 179,
  String  $volume          = '/etc/bgp',
  Array   $docker_volumes  = [],
) {
   $safe_title = regsubst($title, '[^0-9A-Za-z.\-]', '-', 'G');
   sunet::docker_run {"${safe_title}_exabgp":
      image       => 'docker.sunet.se/exabgp',
      imagetag    => $version,
      volumes     => flatten(["${volume}:${volume}:ro", $docker_volumes]),
      ports       => ["${port}:${port}"],
      net         => 'host',
      command     => join(flatten([$config,$extra_arguments])," ")
   } ->
   sunet::snippets::no_icmp_redirects {"no_icmp_redirects_${safe_title}": }
}
