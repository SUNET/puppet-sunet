# Invent frontend server
class sunet::invent::receiver (
  String $docker_tag = '0.0.1-1',
  String $vhost = 'invent.sunet.se'
){

  $endpoints = ['hosts', 'images']
  $nginx_dirs = [ 'acme', 'certs','conf','dhparam','html','vhost' ]

  sunet::docker_compose { 'invent_reciver':
    content          => template('sunet/invent/receiver/docker-compose.yml.erb'),
    service_name     => 'receiver',
    compose_dir      => '/opt/',
    compose_filename => 'docker-compose.yml',
    description      => 'Invent receiver Server',
  }

  file { '/opt/receiver/db':
    ensure => directory
  }
  $endpoints.each |$endpoint| {
    file { "/opt/receiver/${endpoint}":
      ensure => directory
    }
  }

  file { '/opt/receiver/nginx':
    ensure => directory
  }
  $nginx_dirs.each |$dir| {
    file { "/opt/receiver/nginx/${dir}":
      ensure => directory
    }
  }
  sunet::misc::ufw_allow { 'receiver_ports':
    from => 'any',
    port => [80, 443],
  }
}
