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
  $depends             = [],
  $start_on            = [],    # deprecated, used with 'depends' for compatibility
  $stop_on             = [],    # currently not used, kept for compatibility
  $dns                 = [],
  $before_start        = undef, # command executed before starting
  $before_stop         = undef, # command executed before stopping
  $use_unbound         = false, # deprecated, kept for compatibility
) {
  if $use_unbound {
    warning("docker-unbound is deprecated, container name resolution should continue to work using docker network with DNS")
  }

  # Use start_on for docker::run $depends, unless the new argument 'depends' is given
  $_depends = $depends ? {
    []      => any2array($start_on),
    default => flatten([$depends]),
  }

  # If a non-default network is used, make sure it is created before this container starts
  $req = $net ? {
    'host'   => [],
    'bridge' => [],
    default  => [Docker_network[$net]],
  }

  $image_tag = "${image}:${imagetag}"

  # make it possible to use the same docker image more than once on a node
  ensure_resource('docker::image', $image_tag, {
    require => [Package['docker-engine'],
                ],
  })

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
    extra_parameters   => flatten([$extra_parameters]),
    command            => $command,
    dns                => $dns,
    depends            => $_depends,
    require            => flatten([$req,
                                   Docker::Image["${name}_${image_tag}"],
                                   ]),
    before_start       => $before_start,
    before_stop        => $before_stop,
    docker_service     => true,  # the service 'docker' is maintainer by puppet, so depend on it
  }

  # Remove the upstart file created by earlier versions of garethr-docker
  exec { "remove_docker_upstart_job_${name}":
    command => "/bin/rm /etc/init/docker-${name}.conf",
    onlyif  => "/usr/bin/test -f /etc/init/docker-${name}.conf",
  }
}
