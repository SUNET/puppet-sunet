# openbao https://openbao.org
class sunet::openbao(
  String $service_name,
  String $openbao_image = 'quay.io/openbao/openbao',
  String $openbao_tag = '2',
  String $interface = 'ens3',
) {
  # Composefile
  sunet::docker_compose { 'openbao':
    content          => template('sunet/openbao/docker-compose.erb.yml'),
    service_name     => 'openbao',
    compose_dir      => '/opt',
    compose_filename => 'docker-compose.yml',
    description      => 'Openbao',
  }
  $open_ports = [80, 443, 8021]
  $open_ports.each|$port| {
    sunet::nftables::docker_expose { "openbao_${port}":
      allow_clients => 'any',
      port          => $port,
      iif           => $interface,
    }
  }
  -> file { '/opt/openbao/docker-compose.yml':
    ensure  => file,
    content => template('sunet/openbao/docker-compose.erb.yml'),
    owner   => 'root',
    group   => 'root',
    mode    => '0644'
  }
  -> file {'/opt/openbao/nginx':
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  }
  -> file  {'/opt/openbao/nginx/nginx.conf':
    ensure  => file,
    content => template('sunet/openbao/nginx.erb.conf'),
    owner   => 'root',
    group   => 'root',
    mode    => '0644'
  }
}
