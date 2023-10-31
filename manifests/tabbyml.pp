# microk8s cluster node
class sunet::tabbyml(
  String $interface   = 'enp2s0',
  String $tabby_model = 'CodeLlama-13B',
  String $vhost       = 'tabby-lab.sunet.se',
) {
  include sunet::packages::nvidia_container_toolkit
  include sunet::packages::nvidia_cuda_drivers
  sunet::docker_compose { 'tabbyml':
    content          => template('sunet/tabbyml/docker-compose.erb.yml'),
    service_name     => 'tabbyml',
    compose_dir      => '/opt',
    compose_filename => 'docker-compose.yml',
    description      => 'tabbyml',
  }
  $ports = [80, 443]
  $ports.each|$port| {
    sunet::nftables::docker_expose { "port_${port}":
      allow_clients => 'any',
      port          => $port,
      iif           => $interface,
    }
  }
}
