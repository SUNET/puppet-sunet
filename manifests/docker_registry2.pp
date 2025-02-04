# host docker registry with compose
class sunet::docker_registry2 (
  String  $registry_public_hostname   = 'docker.example.com',
  String  $interface                  = 'ens3',
  Array $resolvers                    = [],
  String  $registry_tag               = '2',
  String  $registry_cleanup_basedir   = '/usr/local/bin/clean-registry',
  String  $clean_registry_conf_dir    = '/usr/local/etc/clean-registry',
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
}
