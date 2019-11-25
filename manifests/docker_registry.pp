class sunet::docker_registry (
    String $registry_public_hostname = 'docker.example.com',
    String $fqdn                     = 'docker-prod-1.example.com',
    String $registry_images_basedir  = '/var/lib/registry',
    String $registry_conf_basedir    = '/etc/docker/registry',
    String $apache_conf_basedir      = '/etc/apache2',
    String $registry_cleanup_basedir = '/usr/local/bin/clean-registry',
    String $registry_tag             = '2',
) {
    file { "${registry_conf_basedir}/config.yml":
        ensure  => file,
        mode    => '0640',
        content => template('sunet/docker_registry/config.erb')
    }

    file { "${apache_conf_basedir}/sites-available/registry-auth-ssl.conf":
        ensure  => absent,
    }

    file { "/etc/ssl/certs/${registry_public_hostname}-client-ca.crt":
        ensure  => absent,
    }

    sunet::docker_compose {'docker-registry':
        content          => template('sunet/docker_registry/docker-compose_docker_registry.yml.erb'),
        service_name     => 'docker-registry',
        compose_dir      => $registry_conf_basedir,
        compose_filename => 'docker-compose_docker_registry.yml',
        description      => 'docker-registry service',
    }

    sunet::scriptherder::cronjob { 'check_for_updated_docker_image':
        cmd           => '/usr/local/bin/check_for_updated_docker_image',
        hour          => '1',
        minute        => '5',
        ok_criteria   => ['exit_status=0'],
        warn_criteria => ['max_age=5d']
    }

    package {['python-yaml', 'python-ipaddress', 'python-requests']:
        ensure => installed
    }

    file { "${registry_cleanup_basedir}/clean_registry_cron":
        ensure  => file,
        mode    => '0774',
        content => template('sunet/docker_registry/clean_registry_cron.erb')
    }

    sunet::scriptherder::cronjob { 'clean_registry':
        cmd           => "${registry_cleanup_basedir}/clean_registry_cron",
        weekday       => 'Saturday',
        hour          => '9',
        minute        => '3',
        ok_criteria   => ['exit_status=0'],
        warn_criteria => ['max_age=9d']
    }

    sunet::scriptherder::cronjob { 'clean_registry_test':
        cmd           => "${registry_cleanup_basedir}/clean_registry_cron",
        weekday       => 'Friday',
        hour          => '18',
        minute        => '20',
        ok_criteria   => ['exit_status=0'],
        warn_criteria => ['max_age=9d']
    }

}
