class sunet::flog {

   $postgres_password = safe_hiera('flog_postgres_password')

   file {'/var/docker':
       ensure => 'directory',
   } ->
   sunet::system_user {'postgres-system-user':
       username => 'postgres',
       group    => 'postgres',
   } ->
   sunet::snippets::add_user_to_group { 'postgres_ssl_cert_access':
       username => 'postgres',
       group    => 'ssl-cert',
   } ->
   sunet::system_user {'www-data-system-user':
       username => 'www-data',
       group    => 'www-data',
   } ->
   sunet::system_user {'memcache-system-user':
       username => 'memcache',
       group    => 'memcache',
   } ->
   file {'/var/docker/postgresql_data':
       ensure => 'directory',
       owner  => 'postgres',
       group  => 'root',
       mode   => '0770',
   } ->
   file {'/var/docker/postgresql_data/backup':
       ensure => 'directory',
       owner  => 'postgres',
       group  => 'root',
       mode   => '0770',
   } ->
   file {'/var/log/flog_db':
      ensure => 'directory',
      owner  => 'root',
      group  => 'postgres',
      mode   => '1775',
   } ->
   file {'/var/log/flog_app':
      ensure => 'directory',
      owner  => 'root',
      group  => 'www-data',
      mode   => '1775',
   } ->
   file {'/var/log/flog_app_importer':
      ensure => 'directory',
      owner  => 'root',
      group  => 'www-data',
      mode   => '1775',
   } ->
   file { "/opt/flog/dotenv":
       ensure  => file,
       path    => "/opt/flog/dotenv",
       mode    => '0640',
       content => template('sunet/flog/dotenv.erb'),
   } ->
   file {'/opt/flog/static':
      ensure => 'directory',
      owner  => 'root',
      group  => 'www-data',
      mode   => '1775',
   } ->
   file {'/var/log/flog_cron':
      ensure => 'directory',
      owner  => 'root',
      group  => 'www-data',
      mode   => '1775',
   }
   sunet::docker_run {'flog-db':
      image       => 'docker.sunet.se/library/postgres-9.3',
      volumes     => ['/etc/ssl:/etc/ssl', '/var/docker/postgresql_data/:/var/lib/postgresql/','/var/log/flog_db/:/var/log/postgresql/'],
   }
   sunet::docker_run {'flog-app':
      image   => 'docker.sunet.se/flog/flog_app',
      volumes => ['/opt/flog/dotenv:/opt/flog/.env','/var/log/flog_app/:/opt/flog/logs/','/opt/flog/static/:/opt/flog/flog/static/'],
      env     => ['workers=4','worker_threads=2'],
      depends => ['flog-db']
   }
   sunet::docker_run {'flog-app-import':
      image    => 'docker.sunet.se/flog/flog_app',
      imagetag => 'stable',
      volumes  => ['/opt/flog/dotenv:/opt/flog/.env','/var/log/flog_app_importer/:/opt/flog/logs/'],
      env      => ['workers=4'],
      depends  => ['flog-db']
   }
   sunet::docker_run {'memcached':
      image       => 'docker.sunet.se/library/memcached',
   }
   sunet::docker_run {'flog-nginx':
      image     => 'docker.sunet.se/eduid/nginx',
      ports     => ['443:443'],
      volumes   => ['/opt/flog/nginx/sites-enabled/:/etc/nginx/sites-enabled/', '/etc/dehydrated/certs:/etc/nginx/certs:ro', '/var/log/flog_nginx/:/var/log/nginx', '/opt/flog/static/:/var/www/static/'],
      depends   => ['flog-app']
   }
}
