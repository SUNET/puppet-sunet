class sunet::flog {

   $postgres_password = hiera('flog_postgres_password', 'NOT_SET_IN_HIERA')

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
   file {'/var/log/flog_cron':
      ensure => 'directory',
      owner  => 'root',
      group  => 'www-data',
      mode   => '1775',
   } ->
   file { "/opt/flog/nginx/certs/flog.sunet.se.key":
     ensure  => file,
     path    => "/opt/flog/nginx/certs/flog.sunet.se.key",
     mode    => '0640',
     content => hiera('server_cert_key', 'NOT_SET_IN_HIERA'),
   } ->
   file { "/opt/flog/dotenv":
       ensure  => file,
       path    => "/opt/flog/dotenv",
       mode    => '0640',
       content => template('sunet/flog/dotenv.erb'),
   } ->
   sunet::docker_run {'flog_db':
      image    => 'docker.sunet.se/library/postgres-9.3',
      volumes  => ['/etc/ssl:/etc/ssl', '/var/docker/postgresql_data/:/var/lib/postgresql/','/var/log/flog_db/:/var/log/postgresql/'],
   } ->
   sunet::docker_run {'flog_app':
      image    => 'docker.sunet.se/flog/flog_app',
      volumes  => ['/opt/flog/dotenv:/opt/flog/.env','/var/log/flog/:/opt/flog/logs/'],
   } ->
   sunet::docker_run {'memcached':
      image    => 'docker.sunet.se/library/memcached',
   } ->
   sunet::docker_run {'flog_nginx':
      image     => 'docker.sunet.se/eduid/nginx',
      ports     => ['80:80', '443:443'],
      volumes   => ['/opt/flog/nginx/sites-enabled/:/etc/nginx/sites-enabled/','/opt/flog/nginx/certs/:/etc/nginx/certs', '/var/log/flog_nginx/:/var/log/nginx'],
   }
}
