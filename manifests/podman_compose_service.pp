# Manage a service using podman-compose
define sunet::podman_compose_service(
  String           $compose_file,
  String           $description,
  Optional[String] $service_name = undef,
  Boolean          $pull_on_start = false,
  Array[String]    $service_extras = [],
  Optional[String] $start_command = undef,
) {
  include sunet::systemd_reload

  $_service_name = $service_name ? {
    undef => $name,
    default => $service_name,
  }

  file {
    "/etc/systemd/system/${_service_name}.service":
      content => template('sunet/podmanhost/compose.service.erb'),
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
