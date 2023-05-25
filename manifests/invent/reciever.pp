# Invent frontend server
class sunet::invent::reciever (
  String $docker_tag = '0.0.1-1',
){

  $endpoints = ['hosts', 'images']

  sunet::docker_compose { 'invent_reciver':
    content          => template('sunet/invent/reciever/docker-compose.yml.erb'),
    service_name     => 'reciever',
    compose_dir      => '/opt/',
    compose_filename => 'docker-compose.yml',
    description      => 'Invent Reciever Server',
  }

  file { '/opt/reciever/db':
    ensure => directory
  }

  $endpoints.each |$endpoint| {
    file { "/opt/reciever/${endpoint}":
      ensure => directory
    }
  }
}
