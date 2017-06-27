class sunet::rt {

    # Password for RT's root user
    $rt_root_password = hiera('rt_root_password', 'NOT_SET_IN_HIERA')

    # Password for postgres database
    $postgres_password = hiera('postgres_password', 'NOT_SET_IN_HIERA')

    # The following is used by the PostgreSQL container
    user { 'postgres': ensure => present,
        system => true,
        home   => '/var/lib/postgresql/data',
        shell  => '/bin/sh',
    } ->
    file { '/var/lib/postgresql/data':
        ensure  => directory,
        owner   => 'postgres',
        group   => 'postgres',
        path    => '/var/lib/postgresql/data',
        mode    => '0755',
    }

    # The following is used by the rt-swamid container
    user { 'rt-service': ensure => present,
        system => true,
        home   => '/opt/rt4',
        shell  => '/usr/sbin/nologin',
    }

    sunet::docker_run { 'postgres':
        image    => 'docker.sunet.se/postgres',
        imagetag => '9.5.0',
        volumes  => ['/var/lib/postgresql/data:/var/lib/postgresql/data'],
        env      => ["POSTGRES_DB=postgres",
                     "POSTGRES_USER=postgres",
                     "POSTGRES_PASSWORD=${postgres_password}"],
    }
    sunet::docker_run { 'rt-swamid':
        image    => 'docker.sunet.se/rt-swamid',
        imagetag => 'stable',
        ports    => ['25:25', '80:80', '443:443'],
        volumes  => ['/etc/dehydrated:/etc/ssl',
                     '/dev/log:/dev/log:rw',
                     '/opt/rt4/etc/RT_SiteConfig.pm:/opt/rt4/etc/RT_SiteConfig.pm:ro',
                     '/var/spool/postfix:/var/spool/postfix'],
        env      => ["SP_HOSTNAME=rt.sunet.se",
                     "RT_HOSTNAME=rt.sunet.se",
                     "RT_OWNER=el@sunet.se",
                     "RT_RELAYHOST=smtp.sunet.se",
                     "RT_DEFAULTEMAIL=operations",
                     "RT_Q1=swamid",
                     "RT_Q2=eduroam",
                     "RT_Q3=swamid-bot",
                     "RT_Q4=tcs",
                     "RT_Q5=unused"],
    } ->
    file { '/opt/rt4/etc/RT_SiteConfig.pm':
        ensure  => file,
        owner   => 'rt-service',
        group   => 'www-data',
        path    => '/opt/rt4/etc/RT_SiteConfig.pm',
        mode    => '0660',
        content => template('sunet/rt/rt_siteconfig.erb'),
    }

    file { '/var/lib/postgresql/data/postgres_backup.sh':
        ensure  => file,
        owner   => 'postgres',
        group   => 'postgres',
        path    => '/var/lib/postgresql/data/postgres_backup.sh',
        mode    => '0770',
        content => template('sunet/rt/postgres_backup.erb'),
    }
    sunet::scriptherder::cronjob { 'postgres_backup':
         cmd           => 'docker exec postgres /var/lib/postgresql/data/postgres_backup.sh',
         minute        => '4',
         hour          => '3',
         ok_criteria   => ['exit_status=0', 'max_age=25h'],
         warn_criteria => ['exit_status=0', 'max_age=49h'],
    }

    # Run SQL or Perl here to set RT's root user pwd ???

}
