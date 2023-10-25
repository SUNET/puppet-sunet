# Run bankid-idp with compose
class sunet::bankidp(
  Array $environments_extras = [],
  Array $resolvers = [],
  Array $volumes_extras = [],
  Array $ports_extras = [],
  String $imagetag='latest',
  String $tz = 'Europe/Stockholm',
  String $bankid_home = '/opt/bankidp',
  String $spring_config_import = '/config/service.yml',
  Boolean $prod = true,
  Boolean $app_node = false,
  Boolean $redis_node = false,
  String $instance,
) {
  if $app_node {
    ensure_resource('sunet::misc::create_dir', '/opt/bankidp/config/', { owner => 'root', group => 'root', mode => '0750'})
    file { '/opt/bankidp/config/service.yml':
      content => template('sunet/bankidp/service.yml.erb'),
      mode    => '0755',
    }

    $signing_cert = $prod ? {
      true => 'md-signer2.crt',
      false => 'swamid-qa.crt',
    }

    file { "/opt/bankidp/config/certificates/${signing_cert}":
      ensure  => 'file',
      mode    => '0755',
      owner   => 'root',
      content => file("sunet/bankidp/${signing_cert}")
    }

    sunet::docker_compose { 'bankidp':
      content          => template('sunet/bankidp/docker-compose-bankid-idp.yml.erb'),
      service_name     => 'bankidp',
      compose_dir      => '/opt/',
      compose_filename => 'docker-compose.yml',
      description      => 'Freja ftw',
    }
  }
  if $redis_node {
    sunet::rediscluster { 'redis-cluster':
      numnodes         => 2
    }
  }
}
