# Run exabgp in a standalone Docker container, using --net host
define sunet::lb::exabgp::docker_run(
  Array   $extra_arguments = [],
  String  $version         = 'latest',
  String  $volume          = '/etc/bgp',
  String  $config          = '/etc/bgp/exabgp.conf',
  Array   $docker_volumes  = [],
) {
  $safe_title = regsubst($title, '[^0-9A-Za-z.\-]', '-', 'G');
  sunet::docker_run {"${safe_title}_exabgp":
      image    => 'docker.sunet.se/sunet/docker-sunet-exabgp',
      imagetag => $version,
      volumes  => flatten(["${volume}:${volume}:ro", $docker_volumes]),
      net      => 'host',
      command  => join(flatten([$config, $extra_arguments]),' ')
  }
}
