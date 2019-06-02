class sunet::docker_registry (
    String $registry_public_hostname = 'docker.example.com',
    String $fqdn                     = 'docker-prod-1.example.com',
    String $registry_images_basedir  = '/var/lib/registry',
    String $registry_conf_basedir    = '/etc/docker/registry',
    String $apache_conf_basedir      = '/etc/apache2',
    String $registry_cleanup_basedir = '/usr/local/bin/clean-registry',
    String $registry_tag             = '2',
) {
    ensure_resource('sunet::system_user', 'www-data', {
        username => 'www-data',
        group    => 'www-data',
    })

    exec { 'registry_images_basedir_mkdir':
        command => "/bin/mkdir -p ${registry_images_basedir}",
        unless  => "/usr/bin/test -d ${registry_images_basedir}",
    } ->

    exec { 'registry_conf_basedir':
        command => "/bin/mkdir -p ${registry_conf_basedir}",
        unless  => "/usr/bin/test -d ${registry_conf_basedir}",
    } ->

    exec { 'apache_conf_basedir':
        command => "/bin/mkdir -p ${apache_conf_basedir}/sites-available",
        unless  => "/usr/bin/test -d ${apache_conf_basedir}/sites-available",
    } ->

    file { "${registry_conf_basedir}/config.yml":
        ensure  => file,
        mode    => '0640',
        content => template('sunet/docker_registry/config.erb')
    }

    file { "${apache_conf_basedir}/sites-available/registry-auth-ssl.conf":
        ensure  => file,
        mode    => '0640',
        group   => 'www-data',
        require => Sunet::System_user['www-data'],
        content => template('sunet/docker_registry/registry-auth-ssl.erb')
    }

    file { "/etc/ssl/certs/${registry_public_hostname}-client-ca.crt":
        ensure  => file,
        mode    => '0444',
        group   => 'www-data',
        require => Sunet::System_user['www-data'],
        content => template('sunet/docker_registry/ca.crt.erb')
    }

    sunet::docker_compose {'docker-registry':
        content          => template('sunet/docker_registry/docker-compose_docker_registry.yml.erb'),
        service_name     => 'docker-registry',
        compose_dir      => "${registry_conf_basedir}",
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
    } ->

    file { "${registry_cleanup_basedir}/clean_registry_cron":
        ensure  => file,
        mode    => '0774',
        content => template('sunet/docker_registry/clean_registry_cron.erb')
    } ->

    sunet::scriptherder::cronjob { 'clean_registry':
        cmd           => "${registry_cleanup_basedir}/clean_registry_cron",
        weekday       => 'Saturday',
        hour          => '9',
        ok_criteria   => ['exit_status=0'],
        warn_criteria => ['max_age=9d']
    }

    sunet::scriptherder::cronjob { 'clean_registry_test':
        cmd           => "${registry_cleanup_basedir}/clean_registry_cron",
        weekday       => 'Sunday',
        hour          => '20',
        minute        => '20',
        ok_criteria   => ['exit_status=0'],
        warn_criteria => ['max_age=9d']
    }

}
