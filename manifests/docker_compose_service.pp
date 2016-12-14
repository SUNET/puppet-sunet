# Manage a service using docker-compose
define sunet::docker_compose_service(
  $compose_file,
  $description,
  $service_name = undef,
) {
  if $::operatingsystem == 'Ubuntu' and versioncmp($::operatingsystemrelease, '15.04') >= 0 {
    include sunet::systemd_reload

    $_service_name = $service_name ? {
      undef => $name,
      default => $service_name,
    }

    file {
      "/etc/systemd/system/${_service_name}.service":
        content => template('sunet/dockerhost/compose.service.erb'),
        notify  => [Class['sunet::systemd_reload'],
                    ],
        ;
      '/usr/local/bin/docker-compose':
        mode    => '755',
        content => template('sunet/dockerhost/docker-compose.erb'),
        ;
      '/usr/bin/docker-compose':
        # workaround: docker_compose won't find the binary in /usr/local/bin :(
        ensure  => 'link',
        target  => '/usr/local/bin/docker-compose',
        ;
    }

    service { $_service_name :
      ensure   => 'running',
      enable   => true,
      require  => File["/etc/systemd/system/${_service_name}.service"],
      provider => 'systemd',  # puppet is really bad at figuring this out
    }
  } else {
    err('sunet::docker_compose_service only available on Ubuntu >= 15.04 for now (only systemd is implemented)')
  }
}
