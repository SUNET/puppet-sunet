# mastodon web server
class sunet::mastodon::backend(
  String $db_name                  = 'postgres',
  String $db_user                  = 'postgres',
  String $interface                = 'ens3',
  String $baas2_nodename           = '',
) {
  # Must set in hiera eyaml
  $db_pass=safe_hiera('db_pass')
  $redis_pass=safe_hiera('redis_pass')


  # Composefile
  sunet::docker_compose { 'mastodon_backend':
    content          => template('sunet/mastodon/backend/docker-compose.yml.erb'),
    service_name     => 'mastodon_backend',
    compose_dir      => '/opt',
    compose_filename => 'docker-compose.yml',
    description      => 'Mastodon backend services',
  }
  file { '/opt/mastodon_backend/redis':
    ensure => directory,
  }

  file { '/opt/mastodon_backend/postgres':
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0751',
  }
  file { '/opt/mastodon_backend/redis/server.conf':
    ensure  => file,
    content => template('sunet/mastodon/backend/redis.conf.erb'),
  }


  if $::facts['sunet_nftables_enabled'] == 'yes' {
    sunet::nftables::docker_expose { 'backend_postgres_port' :
      iif           => $interface,
      allow_clients => 'any',
      port          => 5432,
    }
    sunet::nftables::docker_expose { 'backend_redis_port' :
      iif           => $interface,
      allow_clients => 'any',
      port          => 6379,
    }
  } else {
    sunet::misc::ufw_allow { 'backend_ports':
      from => 'any',
      port => ['5432', '6379']
    }
  }

  if ($baas2_nodename) {
    ensure_resource('class','sunet::baas2', {
      nodename    => $baas2_nodename,
      backup_dirs => [
        '/opt/backup/',
      ]
    })
  }

}
