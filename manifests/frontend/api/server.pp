# Setup and run the API
define sunet::frontend::api::server(
  $username                                     = 'sunetfrontend',
  $group                                        = 'sunetfrontend',
  $basedir                                      = '/opt/frontend/api',
  $docker_tag                                   = 'latest',
  Variant[String, Array[String]] $allow_clients = 'any',
  Integer $port                                 = 8080,
  Optional[String] $run_user                    = undef,
)
{
  exec { 'api_mkdir':
    command => "/bin/mkdir -p ${basedir}",
    unless  => "/usr/bin/test -d ${basedir}",
  }

  file {
    "${basedir}/backends":
      ensure => 'directory',
      mode   => '0770',
      group  => $group,
      ;
  }
  sunet::docker_run { "${name}_api":
    image    => 'docker.sunet.se/sunetfrontend-api',
    imagetag => $docker_tag,
    ports    => ["${port}:8080"],
    volumes  => ["${basedir}/backends:/backends",
                '/dev/log:/dev/log',
                '/var/log/sunetfrontend-api:/var/log/sunetfrontend-api',
                ],
    env      => ["runas_user=${username}", "runas_group=${group}"],
    run_user => $run_user,
    require  => [File["${basedir}/backends"]],
  }

  # Internal port 8080 is hardcoded in the image's start.sh (--bind 0.0.0.0:8080) with no env var override.
  # Docker maps $port -> 8080; docker_expose DNATs host-ns traffic to Docker's namespace at $port.
  sunet::nftables::docker_expose { "${name}_api_port":
    allow_clients => $allow_clients,
    port          => $port,
  }
}
