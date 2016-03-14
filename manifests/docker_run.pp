# Common use of docker::run
define sunet::docker_run(
  $image,
  $imagetag            = hiera('sunet_docker_default_tag', 'latest'),
  $volumes             = [],
  $ports               = [],
  $expose              = [],
  $env                 = [],
  $net                 = 'bridge',
  $extra_parameters    = [],
  $command             = undef,
  $hostname            = undef,
  $start_on            = undef,
  $stop_on             = undef,
  $use_unbound         = false,
) {

  # Figure out some parameters that depend on whether this container runs in host or bridge networking mode
  if $net == 'host' {
    $dns = []  # docker refuses --dns with --net host
    $req = []
    $_start_on = $start_on
    $_stop_on = $stop_on
  } else {
    if $use_unbound {
      # If docker was just installed, facter will not know the IP of docker0. Thus the pick.
      # Get default address from Hiera since it is different in Docker 1.8 and 1.9.
     $dns = pick($::ipaddress_docker0, hiera('dockerhost_ip', '172.17.0.1'))
     $req = [Sunet::Docker_run['unbound']]
      # If start_on/stop_on is not explicitly provided, a container in bridge mode should
      # start/stop on the container 'docker-unbound' to make DNS registration work.
      $_start_on = $start_on ? {
        undef => 'docker-unbound',
        default => $start_on,
      }
      $_stop_on = $stop_on ? {
        undef => 'docker-unbound',
        default => $stop_on,
      }
    } else {
      $dns = undef
      $req = []
      $_start_on = $start_on ? {
        undef   => $docker::params::service_name,
        default => $start_on,
      }
      $_stop_on = $stop_on ? {
        undef   => $docker::params::service_name,
        default => $stop_on,
      }
    }
  }

  $image_tag = "${image}:${imagetag}"
  docker::image { "${name}_${image_tag}" :  # make it possible to use the same docker image more than once on a node
    image              => $image_tag,
    require            => [Package['docker-engine'],
                           ],
  } ->

  docker::run { $name :
    use_name           => true,
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
    pre_start          => 'run-parts /usr/local/etc/docker.d',
    post_start         => 'run-parts /usr/local/etc/docker.d',
    pre_stop           => 'run-parts /usr/local/etc/docker.d',
    post_stop          => 'run-parts /usr/local/etc/docker.d',
    start_on           => $_start_on,
    stop_on            => $_stop_on,
    require            => flatten([$req]),
  }

}
