# Manage a service using docker-compose
define sunet::docker_compose_service(
  String           $compose_file,
  String           $description,
  Optional[String] $service_name = undef,
  Boolean          $pull_on_start = false,
  Array[String]    $service_extras = [],
  Optional[String] $start_command = undef,
  Optional[Array]  $compose_require = [],
) {
  if ($::operatingsystem == 'Ubuntu' and versioncmp($::operatingsystemrelease, '15.04') >= 0) or $::operatingsystem == 'Debian' {
    include sunet::systemd_reload

    $_service_name = $service_name ? {
      undef => $name,
      default => $service_name,
    }

    file {
      "/etc/systemd/system/${_service_name}.service":
        content => template('sunet/dockerhost/compose.service.erb'),
        notify  => [Class['sunet::systemd_reload'],],
        ;
    }

    if $compose_require {
        $tmp_require = [ File["/etc/systemd/system/${_service_name}.service"] ]
        $real_require = flatten($tmp_require, $compose_require)
    }
    else
    {
        $real_require = [ File["/etc/systemd/system/${_service_name}.service"] ]
    }

    service { $_service_name :
      ensure   => 'running',
      enable   => true,
      require  => $real_require,
      provider => 'systemd',  # puppet is really bad at figuring this out
    }
  } else {
    err('sunet::docker_compose_service only available on Ubuntu >= 15.04 for now (only systemd is implemented)')
  }
}
