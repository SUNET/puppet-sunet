# Manage a service using docker-compose
define sunet::docker_compose_service(
  String           $compose_file,
  String           $description,
  Optional[String] $service_name = undef,
  Boolean          $pull_on_start = false,
  Array[String]    $service_extras = [],
  Optional[String] $service_alias = undef,
  Optional[String] $start_command = undef,
  Optional[String] $project_name = undef,
) {
  include sunet::systemd_reload

  # Compose derives the project name from the compose file's directory unless told otherwise.
  $_project_args = $project_name ? {
    undef   => '',
    default => " -p ${project_name}",
  }

  $_service_name = $service_name ? {
    undef => $name,
    default => $service_name,
  }

  $_template = $::facts['dockerhost2'] ? {
    yes => 'sunet/dockerhost/compose2.service.erb',
    default => 'sunet/dockerhost/compose.service.erb',
  }

  file {
    "/etc/systemd/system/${_service_name}.service":
      content => template($_template),
      notify  => [Class['sunet::systemd_reload'],
                  ],
      ;
  }

  service { $_service_name :
    ensure   => 'running',
    enable   => true,
    require  => File["/etc/systemd/system/${_service_name}.service"],
    provider => 'systemd',  # puppet is really bad at figuring this out
  }
}
