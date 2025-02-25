# host docker registry with compose
class sunet::docker_registry2 (
  String $registry_public_hostname   = 'docker.example.com',
  String $registry_internal_hostname = 'docker.internal.example.com',
  String $interface                  = 'ens3',
  Array $resolvers                   = [],
  String $registry_tag               = '2',
  String $registry_cleanup_basedir   = '/usr/local/bin/clean-registry',
  String $clean_registry_conf_dir    = '/usr/local/etc/clean-registry',
  String $registry_s3backup_hostname = 's3.sunet.se',
  String $registry_s3backup_bucket   = 'docker-registry-backup',
) {

  sunet::nftables::docker_expose { 'https':
    iif           => $interface,
    allow_clients => ['any'],
    port          => 443,
  }
  sunet::nftables::docker_expose { 'http':
    iif           => $interface,
    allow_clients => ['any'],
    port          => 80,
  }

  file {
    default:
      ensure => file,
    ;
    '/opt/docker-registry/docker/docker-registry-auth':
      ensure => directory,
    ;
    '/opt/docker-registry/docker/docker-registry-auth/Dockerfile':
      content => file('sunet/docker_registry2/docker/docker-registry-auth/Dockerfile'),
    ;
    '/opt/docker-registry/docker/docker-registry-auth/registry-auth-ssl.conf':
      content => file('sunet/docker_registry2/docker/docker-registry-auth/registry-auth-ssl.conf'),
    ;
    '/opt/docker-registry/docker/docker-registry-auth/setup.sh':
      mode    => '0755',
      content => file('sunet/docker_registry2/docker/docker-registry-auth/setup.sh'),
    ;
    '/opt/docker-registry/docker/docker-registry-auth/start.sh':
      mode    => '0755',
      content => file('sunet/docker_registry2/docker/docker-registry-auth/start.sh'),
    ;
    '/opt/docker-registry/infra-ca.crt':
      content => file('sunet/docker_registry2/infra-ca.crt'),
    ;
  }

  sunet::docker_compose { 'docker-registry':
    content          => template('sunet/docker_registry2/docker-compose-docker-registry.yml.erb'),
    service_name     => 'docker-registry',
    compose_dir      => '/opt/',
    compose_filename => 'docker-compose.yml',
    description      => 'docker-registry',
  }

  package { ['python3-requests', 'python3-dateutil']:
    ensure => installed
  }

  file {
    $registry_cleanup_basedir:
      ensure => directory,
    ;
    $clean_registry_conf_dir:
      ensure => directory,
    ;
  }

  file {
    default:
      ensure => file,
      mode   => '0755',
    ;
    "${registry_cleanup_basedir}/clean_registry_cron":
      content => template('sunet/docker_registry2/clean_registry_cron.erb'),
    ;
    "${registry_cleanup_basedir}/clean_registry.py":
      content => file('sunet/docker_registry2/clean_registry.py'),
    ;
    "${registry_cleanup_basedir}/registry.py":
      content => file('sunet/docker_registry2/registry.py'),
    ;
    "${clean_registry_conf_dir}/config_file.yaml":
      mode    => '0644',
      content => file('sunet/docker_registry2/config_file.yaml'),
      replace => false,
    ;
  }

  sunet::scriptherder::cronjob { 'clean_registry':
    cmd           => "${registry_cleanup_basedir}/clean_registry_cron",
    weekday       => 'Saturday',
    hour          => '9',
    minute        => '3',
    ok_criteria   => ['exit_status=0'],
    warn_criteria => ['max_age=9d']
  }

  if lookup('registry_s3backup_config', undef, undef, undef) != undef {
    $s3cmd = [
      's3cmd',
      '--config=/opt/docker-registry/s3backup_config',
      "--host=${registry_s3backup_hostname}",
      "--host-bucket=%(bucket).${registry_s3backup_hostname}",
    ]

    package { 's3cmd':
      ensure => installed
    }
    -> sunet::snippets::secret_file { '/opt/docker-registry/s3backup_config':
      hiera_key => 'registry_s3backup_config',
    }
    -> exec { "${registry_s3backup_hostname}_${registry_s3backup_bucket}":
      command => $s3cmd + ['mb', "s3://${registry_s3backup_bucket}"],
    }

    sunet::scriptherder::cronjob { 'registry_s3backup':
      cmd           => shellquote($s3cmd,
        'sync', '/var/lib/registry/docker/registry/v2', "s3://${registry_s3backup_bucket}",
      ).regsubst('\%', '\\%'), # crontab replaces % signs with newlines
      hour          => '2',
      minute        => '3',
      ok_criteria   => ['exit_status=0'],
      warn_criteria => ['max_age=2d'],
    }
  }
}
