# Setup and run the API
define sunet::frontend::api::server(
  $username   = 'sunetfrontend',
  $group      = 'sunetfrontend',
  $basedir    = '/opt/frontend/api',
  $docker_tag = 'latest',
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
    net      => 'host',
    volumes  => ["${basedir}/backends:/backends",
                '/dev/log:/dev/log',
                '/var/log/sunetfrontend-api:/var/log/sunetfrontend-api',
                ],
    require  => [File["${basedir}/backends"]],
  }
}
