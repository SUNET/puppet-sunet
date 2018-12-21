class sunet::comanage (
    $home          = '/root/comanage',
    $comanage_dir  = '/opt/comanage-registry-deployment',
) {

    # Create the system users needed
    sunet::system_user {'postgres': username => 'postgres', group => 'postgres' }
    sunet::system_user {'_shibd': username => '_shibd', group => '_shibd' }
    sunet::system_user {'openldap': username => 'openldap', group => 'openldap' }

    # Bootstrap docker working directory and comanage-registry itself
    file { "${comanage_dir}":
        ensure  => directory,
        owner   => 'root',
        group   => 'root',
        path    => "${comanage_dir}",
        mode    => '0755',
    }
    file { "${home}":
        ensure  => directory,
        owner   => 'root',
        group   => 'root',
        path    => "${home}",
        mode    => '0755',
    }

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

    file { "${comanage_dir}/slapd-ldif":
        ensure  => directory,
        owner   => 'openldap',
        group   => 'openldap',
        path    => "${comanage_dir}/slapd-ldif",
        mode    => '0755',
    }

    # Create all the secrets from Hiera
    $postgres_password = hiera('postgres_password', 'NOT_SET_IN_HIERA')
    $comanage_postgres_password = hiera('comanage_postgres_password', 'NOT_SET_IN_HIERA')
    $openldap_root_password = hiera('openldap_root_password', 'NOT_SET_IN_HIERA')
    $comanage_email_password = hiera('comanage_email_password', 'NOT_SET_IN_HIERA')
    $comanage_security_salt = hiera('comanage_security_salt', 'NOT_SET_IN_HIERA')
    $comanage_security_seed = hiera('comanage_security_seed', 'NOT_SET_IN_HIERA')
    $openldap_olc_root_dn_password = hiera('openldap_olc_root_dn_password', 'NOT_SET_IN_HIERA')
    $openldap_syncrepl_system_password = hiera('openldap_syncrepl_system_password', 'NOT_SET_IN_HIERA')
    $openldap_registry_system_password = hiera('openldap_registry_system_password', 'NOT_SET_IN_HIERA')
    $openldap_samlproxy_system_password = hiera('openldap_samlproxy_system_password', 'NOT_SET_IN_HIERA')

    # FIXME: Horrible but I have to do this to be able to mount passwd/group due to COmanage issue:
    # https://github.com/Internet2/comanage-registry-docker/issues/11
    file { '/etc/shibboleth/shibboleth2.xml':
        ensure  => file,
        owner   => 'root',
        group   => 'root',
        path    => '/etc/shibboleth/shibboleth2.xml',
        mode    => '0644',
        content => template('sunet/comanage/shibboleth2.erb'),
    }

    #Contents of slap-data directory
    file { "${comanage_dir}/slapd-data/bootstrap.ldif":
        ensure  => file,
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
        content => template('sunet/comanage/bootstrap.ldif.erb'),
    }
    file { "${comanage_dir}/slapd-data/olcAccess.ldif":
        ensure  => file,
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
        content => template('sunet/comanage/olcAccess.ldif.erb'),
    }
    #the password for the OpenLDAP admin with dn cn=admin,dc=sunet,dc=se
    file { "${comanage_dir}/secrets/olc_root_dn_password":
        ensure  => file,
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
        content => template('sunet/comanage/olc_root_dn_password.erb'),
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
         cmd           => 'docker exec comanage_comanage-registry-database_1 /opt/comanage-backup/postgres_backup.sh',
         minute        => '4',
         hour          => '3',
         ok_criteria   => ['exit_status=0', 'max_age=25h'],
         warn_criteria => ['exit_status=0', 'max_age=49h'],
    }

}
