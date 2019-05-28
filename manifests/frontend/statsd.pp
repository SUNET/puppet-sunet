# Setup and run one statsd per frontend
define sunet::frontend::statsd(
  String           $docker_image    = 'docker.sunet.se/eduid/statsd',
  String           $docker_imagetag = 'stable',
  Optional[String] $repeat_host     = undef,
  String           $repeat_port     = '8125',
)
{
  if ($repeat_host) {
    $env = ["REPEAT_HOST=${repeat_host}",
            "REPEAT_PORT=${repeat_port}",
            ]
  } else {
    $env = []
  }

  sunet::docker_run { "${name}_statsd":
    image    => $docker_image,
    imagetag => $docker_imagetag,
    expose   => ['8125/udp'],
    env      => $env,
  }
}
