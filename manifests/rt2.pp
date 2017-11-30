class sunet::rt2 {

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
        image    => 'rt-swamid',
        imagetag => 'latest',
        ports    => ['25:25', '80:80', '443:443'],
        volumes  => ['/dev/log:/dev/log:rw',
                     '/etc/ssl:/etc/ssl',
                     '/var/spool/postfix:/var/spool/postfix'],
        env      => ["SP_HOSTNAME=rt-test.sunet.se",
                     "RT_HOSTNAME=rt-test.sunet.se",
                     "RT_OWNER=el@sunet.se",
                     "RT_RELAYHOST=smtp.sunet.se",
                     "RT_DEFAULTEMAIL=operations",
                     "RT_Q1=swamid",
                     "RT_Q2=eduroam",
                     "RT_Q3=swamid-bot",
                     "RT_Q4=tcs",
                     "RT_Q5=unused",
                     "POSTGRES_PASSWORD=${postgres_password}",
                     "RT_PASSWORD=${rt_root_password}"],
    }

    # Run SQL or Perl here to set RT's root user pwd ???

}
