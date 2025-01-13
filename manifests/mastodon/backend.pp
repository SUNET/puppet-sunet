# mastodon web server
class sunet::mastodon::backend(
  String $db_name                        = 'postgres',
  String $db_user                        = 'postgres',
  String $interface                      = 'ens3',
  Variant[String, Undef] $baas2_nodename = undef,
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
      monitor_backups => false,
      nodename        => $baas2_nodename,
      backup_dirs     => [
        '/opt/backups/',
      ]
    })

    # Clean up old backup job
    cron { 'run_backups':
      ensure  => 'absent',
      command => '/opt/scripts/backup.sh',
      user    => 'root',
      minute  => '31',
      hour    => '*',
    }
    file { '/opt/scripts/backup.sh':
      ensure  => 'absent',
    }
    #

    file { '/opt/mastodon_backend/scripts':
      ensure => directory,
    }
    file { '/opt/mastodon_backend/scripts/backup.sh':
      ensure  => file,
      owner   => 'root',
      group   => 'root',
      mode    => '0700',
      content => template('sunet/mastodon/backend/backup.erb.sh'),
    }

    sunet::scriptherder::cronjob { 'backup2baas':
      cmd           => '/opt/mastodon_backend/scripts/backup.sh',
      minute        => '31',
      ok_criteria   => ['exit_status=0', 'max_age=2h'],
      warn_criteria => ['exit_status=1', 'max_age=5h'],
    }
  }
  sunet::scriptherder::cronjob { 'vacuum_postgres':
    cmd           => '/usr/bin/docker exec -u postgres postgres psql --command "VACUUM FULL;"',
    minute        => '3',
    hour          => '3',
    monthday      => '3',
    ok_criteria   => ['exit_status=0', 'max_age=32d'],
    warn_criteria => ['exit_status=1', 'max_age=64d'],
  }

}
