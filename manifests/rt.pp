class sunet::rt (
    Array[String] $cosmos_site_env = [],
) {

    # Password for RT's root user
    $rt_root_password = safe_hiera('rt_root_password')

    # Password for postgres database
    $postgres_password = safe_hiera('postgres_password')

    # The following is used by the PostgreSQL container
    user { 'postgres': ensure => present,
        system                => true,
        home                  => '/var/lib/postgresql/data',
        shell                 => '/bin/sh',
    }
    -> file { '/var/lib/postgresql/data':
        ensure => directory,
        owner  => 'postgres',
        group  => 'postgres',
        path   => '/var/lib/postgresql/data',
        mode   => '0755',
    }

    # The following is used by the rt-swamid container
    user { 'rt-service': ensure => present,
        system                  => true,
        home                    => '/opt/rt4',
        shell                   => '/usr/sbin/nologin',
    }

    sunet::docker_run { 'postgres':
        image    => 'docker.sunet.se/postgres',
        imagetag => '9.5.0',
        volumes  => ['/var/lib/postgresql/data:/var/lib/postgresql/data'],
        env      => ['POSTGRES_DB=postgres',
                    'POSTGRES_USER=postgres',
                    "POSTGRES_PASSWORD=${postgres_password}"],
    }
    sunet::docker_run { 'rt-swamid':
        image    => 'docker.sunet.se/rt-swamid',
        imagetag => 'latest',
        ports    => ['25:25', '80:80', '443:443'],
        volumes  => ['/dev/log:/dev/log:rw',
                    '/etc/dehydrated:/etc/ssl',
                    '/var/spool/postfix:/var/spool/postfix'],
        env      => flatten(['RT_OWNER=el@sunet.se',
                    'RT_RELAYHOST=smtp.sunet.se',
                    'RT_DEFAULTEMAIL=operations',
                    'RT_Q1=swamid',
                    'RT_Q2=eduroam',
                    'RT_Q3=swamid-bot',
                    'RT_Q4=tcs',
                    'RT_Q5=zoom',
                    'RT_Q6=connect',
                    'RT_Q7=play',
                    "POSTGRES_PASSWORD=${postgres_password}",
                    "RT_PASSWORD=${rt_root_password}",
                    $cosmos_site_env]),
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

    file { '/usr/local/bin/shredder.pl':
        ensure  => file,
        owner   => 'root',
        group   => 'root',
        path    => '/usr/local/bin/shredder.pl',
        mode    => '0755',
        content => template('sunet/rt/shredder.erb'),
    }
    sunet::scriptherder::cronjob { 'rt_spam_shredder':
        cmd           => '/usr/bin/perl /usr/local/bin/shredder.pl',
        minute        => '2',
        hour          => '2',
        ok_criteria   => ['exit_status=0', 'max_age=25h'],
        warn_criteria => ['exit_status=0', 'max_age=49h'],
    }

    # Run SQL or Perl here to set RT's root user pwd ???

}
