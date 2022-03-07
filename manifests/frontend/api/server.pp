# Setup and run the API
define sunet::frontend::api::server(
  String $username   = 'sunetfrontend',
  String $group      = 'sunetfrontend',
  String $basedir    = '/opt/frontend/api',
  String $docker_tag = 'latest',
  Integer $api_port = 8080,
)
{
  ensure_resource('sunet::system_user', $username, {
    username => $username,
    group    => $group,
  })

  exec { 'api_mkdir':
    command => "/bin/mkdir -p ${basedir}",
    unless  => "/usr/bin/test -d ${basedir}",
  }

  file {
    "${basedir}/backends":
      ensure  => 'directory',
      mode    => '0770',
      group   => $group,
      require => Sunet::System_user[$username],
      ;
  }
  sunet::docker_run { "${name}_api":
    image    => 'docker.sunet.se/sunetfrontend-api',
    imagetag => $docker_tag,
    #net      => 'host',
    ports    => ["${api_port}:8080"],
    volumes  => [
      "${basedir}/backends:/backends",
      '/var/log/sunetfrontend-api:/var/log/sunetfrontend-api',
      ],
    require  => [File["${basedir}/backends"]],
  }
}
