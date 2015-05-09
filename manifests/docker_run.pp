# Common use of docker::run
define sunet::docker_run(
  $image,
  $imagetag            = hiera('sunet_docker_default_tag', 'latest'),
  $volumes             = [],
  $ports               = [],
  $env                 = [],
  $net                 = 'bridge',
  $extra_parameters    = [],
  $command             = "",
  $hostname            = undef,
) {

  # Make container use unbound resolver on dockerhost
  # If docker was just installed, facter will not know the IP of docker0. Thus the pick.
  $dns = $net ? {
    'host'  => [],  # docker refuses --dns with --net host
    default => [pick($::ipaddress_docker0, '172.17.42.1')],
  }

  $image_tag = "${image}:${imagetag}"
  docker::image { $image_tag : } ->

  docker::run {$name :
    use_name           => true,
    image              => $image_tag,
    volumes            => flatten([$volumes,
                           '/etc/passwd:/etc/passwd:ro',  # uid consistency
                           '/etc/group:/etc/group:ro',    # gid consistency
                           ]),
    hostname           => $hostname,
    ports              => $ports,
    env                => $env,
    net                => $net,
    extra_parameters   => flatten([$extra_parameters,
                                   '--rm',
                                   ]),
    dns                => $dns,
    verify_checksum    => false,    # Rely on registry security for now. eduID risk #31.
    command            => $command,
    pre_start          => 'run-parts /usr/local/etc/docker.d',
    post_start         => 'run-parts /usr/local/etc/docker.d',
    pre_stop           => 'run-parts /usr/local/etc/docker.d',
  }

}
