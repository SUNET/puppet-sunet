# Invent frontend server
class sunet::invent::reciever (
  String $docker_tag = '0.0.1-1',
  String $vhost = 'invent.sunet.se'
){

  $endpoints = ['hosts', 'images']
  $nginx_dirs = [ 'acme', 'certs','conf','dhparam','html','vhost' ]

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

  file { '/opt/reciever/nginx':
    ensure => directory
  }
  $nginx_dirs.each |$dir| {
    file { "/opt/reciever/nginx/${dir}":
      ensure => directory
    }
  }
  sunet::misc::ufw_allow { 'reciever_ports':
    from => 'any',
    port => [80, 443],
  }
}
