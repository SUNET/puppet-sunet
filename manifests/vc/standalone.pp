class sunet::vc::standalone(
  String  $vc_version="latest",
  String  $mongodb_version="4.0.10",
  String  $mockca_sleep="20",
  String  $ca_token="",
  Boolean $production=false,
  #hash with basic_auth key/value
) {

  file { '/opt/vc':
    ensure  => directory,
    mode    =>  '0755',
    owner   =>  'root',
    group   =>  'root',
  }

  file { '/opt/vc/compose':
    ensure  => directory,
    mode    =>  '0755',
    owner   =>  'root',
    group   =>  'root',
  }

  #file { '/opt/vc/compose/docker-compose.yml':
  #  ensure  => file,
  #  mode    => '0644',
  #  owner   => 'root',
  #  group   => 'root',
  #  content =>  template("sunet/vc/docker-compose_mock.yml.erb")
  #}

  # Compose
  sunet::docker_compose { 'vc':
    content          => template('sunet/vc/docker-compose_mock.yml.erb'),
    service_name     => 'vc',
    compose_dir      => '/opt',
    compose_filename => 'docker-compose.yml',
    description      => 'VC service',
  }
}
