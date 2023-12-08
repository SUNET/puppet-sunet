# Setup and run the API
define sunet::lb::api::server(
  String $username   = 'fe-api',
  String $group      = 'fe-api',
  String $basedir    = '/opt/frontend/api',
  String $docker_tag = 'latest',
  Integer $api_port = 8080,
  Boolean $docker_run = true,
)
{
  # ensure_resource('sunet::system_user', $username, {
  #   username => $username,
  #   group    => $group,
  # })

  ensure_resource('sunet::misc::create_dir', $basedir, {
    owner => 'root',
    group => 'root',
    mode  => '0755',
  })
  ensure_resource('sunet::misc::create_dir', "${basedir}/backends", {
    owner => 'root',
    group => $group,
    mode  => '0770',
  })

  if $docker_run {
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
}
