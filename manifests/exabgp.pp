include stdlib

define sunet::exabgp(
   $extra_arguments = [], 
   $config          = undef,
   $version         = 'latest',
   $port            = 179
) {
   $safe_title = regsubst($title, '[^0-9A-Za-z.\-]', '-', 'G');
   $cfg = $config ? {
      undef    => $name,
      default  => $config
   }
   sunet::docker_run {"${safe_title}_exabgp":
      image    => 'docker.sunet.se/exabgp',
      imagetag => $version,
      volumes  => ["${cfg}:${cfg}:ro"],
      ports    => ["${port}:${port}"],
      command  => join(flatten([$cfg,$extra_arguments])," "),
   } ->
   sunet::snippets::no_icmp_redirects {"no_icmp_redirects_${safe_title}": }
}
