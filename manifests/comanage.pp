class sunet::comanage (
    $home          = '/root/comanage',
    $comanage_dir  = '/opt/comanage-registry-deployment',
) {

    # Create the system users needed
    sunet::system_user {'postgres': username => 'postgres', group => 'postgres' }
    sunet::system_user {'_shibd': username => '_shibd', group => '_shibd' }
    sunet::system_user {'openldap': username => 'openldap', group => 'openldap' }

    # Create the directories that the above system users use/need
    file { "${comanage_dir}/postgres-data":
        ensure  => directory,
        owner   => 'postgres',
        group   => 'postgres',
        path    => "${comanage_dir}/postgres-data",
        mode    => '0755',
    }
    file { '/var/run/shibboleth':
        ensure  => directory,
        owner   => '_shibd',
        group   => '_shibd',
        path    => '/var/run/shibboleth',
        mode    => '0755',
    }
    file { '/var/run/apache2':
        ensure  => directory,
        owner   => 'www-data',
        group   => 'www-data',
        path    => '/var/run/apache2',
        mode    => '0755',
    }
    file { '/var/run/slapd':
        ensure  => directory,
        owner   => 'openldap',
        group   => 'openldap',
        path    => '/var/run/slapd',
        mode    => '0755',
    }
    file { "${comanage_dir}/slapd-config":
        ensure  => directory,
        owner   => 'openldap',
        group   => 'openldap',
        path    => "${comanage_dir}/slapd-config",
        mode    => '0755',
   }
    file { "${comanage_dir}/slapd-data":
        ensure  => directory,
        owner   => 'openldap',
        group   => 'openldap',
        path    => "${comanage_dir}/slapd-data",
        mode    => '0755',
    }

    $content = template('sunet/comanage/docker-compose_comanage.yml.erb')
    sunet::docker_compose {'comanage_docker_compose':
        service_name => 'comanage',
        description  => 'comanage service',
        compose_dir  => "${home}",
        content => $content,
    }

    # Get a postgres backup up and running
    file { "/opt/comanage-backup/postgres":
        ensure  => directory,
        owner   => 'postgres',
        group   => 'postgres',
        path    => "/opt/comanage-backup/postgres",
        mode    => '0755',
    }
    file { '/opt/comanage-backup/postgres_backup.sh':
        ensure  => file,
        owner   => 'postgres',
        group   => 'postgres',
        path    => '/opt/comanage-backup/postgres_backup.sh',
        mode    => '0770',
        content => template('sunet/comanage/postgres_backup.erb'),
    }
    sunet::scriptherder::cronjob { 'postgres_backup':
         cmd           => 'docker exec postgres /opt/comanage-backup/postgres_backup.sh',
         minute        => '4',
         hour          => '3',
         ok_criteria   => ['exit_status=0', 'max_age=25h'],
         warn_criteria => ['exit_status=0', 'max_age=49h'],
    }

}
