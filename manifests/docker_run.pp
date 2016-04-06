# Common use of docker::run
define sunet::docker_run(
  $image,
  $imagetag            = hiera('sunet_docker_default_tag', 'latest'),
  $volumes             = [],
  $ports               = [],
  $expose              = [],
  $env                 = [],
  $net                 = hiera('sunet_docker_default_net', 'docker'),
  $extra_parameters    = [],
  $command             = undef,
  $hostname            = undef,
  $start_on            = [],  # used with 'depends'
  $stop_on             = [],  # currently not used
  $dns                 = [],
  $before_start        = undef,
  $before_stop         = undef,
  $use_unbound         = false,
) {

  if $use_unbound {
    warning("docker-unbound is deprecated, container name resolution should continue to work using docker network with DNS")
  }

  $req = $net ? {
    'host'   => [],
    'bridge' => [],
    default  => [Docker_network[$net]],
  }

  $image_tag = "${image}:${imagetag}"
  docker::image { "${name}_${image_tag}" :  # make it possible to use the same docker image more than once on a node
    image              => $image_tag,
    require            => [Package['docker-engine'],
                           ],
  } ->

  docker::run { $name :
    image              => $image_tag,
    volumes            => flatten([$volumes,
                                   '/etc/passwd:/etc/passwd:ro',  # uid consistency
                                   '/etc/group:/etc/group:ro',    # gid consistency
                                   ]),
    hostname           => $hostname,
    ports              => $ports,
    expose             => $expose,
    env                => $env,
    net                => $net,
    extra_parameters   => flatten([$extra_parameters,
                                   '--rm',
                                   ]),
    command            => $command,
    dns                => $dns,
    depends            => $start_on,
    require            => flatten([$req]),
    before_start       => $before_start,
    before_stop        => $before_stop,
  }

}
