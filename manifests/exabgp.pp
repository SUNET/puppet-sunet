include stdlib

define sunet::exabgp(
   $extra_arguments = [], 
   $config          = "/etc/bgp/exabgp.conf",
   $version         = 'latest',
   $port            = 179,
   $volume          = "/etc/bgp"
) {
   $safe_title = regsubst($title, '[^0-9A-Za-z.\-]', '-', 'G');
   sunet::docker_run {"${safe_title}_exabgp":
      image       => 'docker.sunet.se/exabgp',
      imagetag    => $version,
      volumes     => ["${volume}:${volume}:ro"],
      ports       => ["${port}:${port}"],
      environment => ["CONFIG=${config}"],
      command     => join($extra_arguments," ")
   } ->
   sunet::snippets::no_icmp_redirects {"no_icmp_redirects_${safe_title}": }
}
