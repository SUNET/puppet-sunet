class sunet::norduni {

    $postgres_master_password = safe_hiera('postgres_master_password')
    $postgres_ni_password = safe_hiera('postgres_ni_password')
    $noclook_secret_key = safe_hiera('noclook_secret_key')
    # TODO: Take tls info as arguments
    $norduni_tls_cert = 'nidev-consumer_nordu_net.crt'
    $norduni_tls_key = 'nidev-consumer_nordu_net.key'

    # Create local users for mapping to docker containers
    user { 'ni': ensure => present,
        gid    => 'ni',
        system => true,
        home   => '/var/opt/norduni',
        shell  => '/bin/bash',
    } ->
    sunet::system_user {'neo4j': username => 'neo4j', group => 'neo4j' }
    sunet::system_user {'postgres': username => 'postgres', group => 'postgres' }
    sunet::system_user {'www-data': username => 'www-data', group => 'www-data' }

    # Directories/files that will be volume mounted in containers
    file { '/var/opt/norduni':
      ensure  => directory,
      owner   => 'ni',
      group   => 'ni',
    } ->
    file { '/var/opt/norduni/data':
      ensure  => directory,
      owner   => 'ni',
      group   => 'ni',
    } ->
    file { '/var/opt/norduni/noclook':
      ensure  => directory,
      owner   => 'ni',
      group   => 'ni',
      recurse => true,
    } ->
    file { '/var/opt/norduni/noclook/etc':
      ensure  => directory,
      owner   => 'ni',
      group   => 'ni',
      recurse => true,
    } ->
    file { '/var/opt/norduni/noclook/etc/dotenv':
        ensure  => file,
        owner   => 'ni',
        group   => 'ni',
        mode    => '0440',
        content => template('sunet/norduni/norduni_dotenv.erb'),
    } ->
    file { '/var/opt/norduni/noclook/staticfiles':
      ensure  => directory,
      owner   => 'ni',
      group   => 'www-data',
      recurse => true,
    } ->
    file { '/var/opt/norduni/noclook/media':
      ensure  => directory,
      owner   => 'ni',
      group   => 'www-data',
      recurse => true,
    } ->
    file { '/var/opt/norduni/nginx':
      ensure  => directory,
      owner   => 'www-data',
      group   => 'www-data',
      recurse => true,
    } ->
    file { '/var/opt/norduni/nginx/etc':
      ensure  => directory,
      owner   => 'www-data',
      group   => 'www-data',
      recurse => true,
    } ->
    file { '/var/opt/norduni/nginx/etc/default.conf':
        ensure  => file,
        owner   => 'www-data',
        group   => 'www-data',
        mode    => '0440',
        content => template('sunet/norduni/nginx_conf.erb'),
    } ->
    file { '/var/opt/norduni/postgres':
      ensure  => directory,
      owner   => 'postgres',
      group   => 'postgres',
      recurse => true,
    } ->
    file { '/var/opt/norduni/postgres/init':
      ensure  => directory,
      owner   => 'postgres',
      group   => 'postgres',
      recurse => true,
    } ->
    file { '/var/opt/norduni/postgres/init/init-noclook-db.sh':
        ensure  => file,
        owner   => 'postgres',
        group   => 'postgres',
        mode    => '0770',
        content => template('sunet/norduni/init-noclook-db.sh.erb'),
    } ->
    file { '/var/opt/norduni/data/postgresql':
      ensure  => directory,
      owner   => 'postgres',
      group   => 'postgres',
      recurse => true,
    } ->
    file { '/var/opt/norduni/data/neo4j':
      ensure  => directory,
      owner   => 'neo4j',
      group   => 'neo4j',
      recurse => true,
    } ->
    file { '/var/log/norduni':
        ensure  => directory,
        owner   => 'ni',
        group   => 'ni',
        mode    => '0755',
    } ->
    file { '/var/log/nginx':
        ensure  => directory,
        owner   => 'www-data',
        group   => 'www-data',
        mode    => '0755',
    } ->
    file { '/var/opt/norduni/.ssh':
      ensure  => directory,
      owner   => 'ni',
      group   => 'ni',
      recurse => true,
    } ->
    # The private key ssh used for pulling/pushing nistore
    # The public part is distributed using Cosmos.
    sunet::snippets::secret_file { '/var/opt/norduni/.ssh/nigit':
        hiera_key   => 'nigit_key',
        owner       => 'ni',
        group       => 'ni',
    } ->
    # The private key for the certificate used by Nginx
    # The public part is distributed using Cosmos.
    sunet::snippets::secret_file { "/var/opt/norduni/nginx/ssl/${norduni_tls_key}":
        hiera_key => 'norduni_tls_key',
        owner     => 'www-data',
        group     => 'www-data',
    } ->
    exec { 'create_dhparam_pem':
        command => '/usr/bin/openssl dhparam -out /var/opt/norduni/nginx/ssl/dhparam.pem 2048',
        unless  => '/usr/bin/test -s /var/opt/norduni/nginx/ssl/dhparam.pem',
    }

    sunet::docker_run { 'norduni-postgres':
        image    => 'postgres',
        imagetag => 'latest',
        volumes  => ['/var/opt/norduni/data/postgresql:/var/lib/postgresql/data/', '/var/opt/norduni/postgres/init/init-noclook-db.sh:/docker-entrypoint-initdb.d/init-noclook-db.sh'],
        env      => ["POSTGRES_USER=postgres",
                     "POSTGRES_PASSWORD=${postgres_master_password}"]
    }

    sunet::docker_run { 'norduni-neo4j':
        image    => 'neo4j',
        imagetag => 'latest',
        volumes  => ['/var/opt/norduni/data/neo4j:/data'],
        env      => ["NEO4J_AUTH=neo4j/docker"]
    }

    sunet::docker_run { 'norduni-noclook':
        image    => 'docker.sunet.se/norduni/noclook',
        imagetag => 'latest',
        volumes  => ['/var/opt/norduni/noclook/etc/dotenv:/var/opt/norduni/norduni/src/niweb/.env:ro',
                     '/var/opt/norduni/noclook/etc/full-update.conf:/var/opt/norduni/norduni/src/scripts/full-update.conf:ro',
                     '/var/opt/norduni/noclook/staticfiles:/var/opt/norduni/staticfiles',
                     '/var/opt/norduni/noclook/media:/var/opt/norduni/media',
                     '/var/log/norduni:/var/log/norduni',
                     '/var/opt/norduni/nistore:/var/opt/nistore'],
        env      => ["DJANGO_SETTINGS_MODULE=niweb.settings.dev",
                     "CONFIG_FILE=/var/opt/norduni/norduni/src/niweb/.env",
                     "STATIC_ROOT=/var/opt/norduni/staticfiles",
                     "LOG_PATH=/var/log/norduni"],
        extra_parameters => ['--restart=on-failure:10'],
        depends  => ['norduni-postgres', 'norduni-neo4j']
    }

    sunet::docker_run { 'norduni-nginx':
        image            => 'docker.sunet.se/eduid/nginx',
        imagetag         => 'latest',
        ports            => ['80:80', '443:443'],
        volumes          => ['/var/log/nginx:/var/log/nginx',
                             '/var/opt/norduni/nginx/etc/default.conf:/etc/nginx/sites-enabled/default:ro',
                             '/var/opt/norduni/nginx/ssl/:/etc/nginx/ssl/:ro',
                             '/var/opt/norduni/noclook/staticfiles:/usr/share/nginx/html/static'],
        extra_parameters => ['--restart=on-failure:10'],
        depends          => ['norduni-noclook']
    }

}
