# microk8s cluster node
class sunet::tabbyml(
  String $interface   = 'enp2s0',
  String $tabby_model = 'CodeLlama-13B',
  String $vhost       = 'tabby-lab.sunet.se',
) {
  $vhost_password = lookup('vhost_password')
  include sunet::packages::apache2_utils
  include sunet::packages::git
  include sunet::packages::git_lfs
  include sunet::packages::nvidia_container_toolkit
  include sunet::packages::nvidia_cuda_drivers
  sunet::docker_compose { 'tabbyml':
    content          => template('sunet/tabbyml/docker-compose.yml.erb'),
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
  exec { 'git_clone_code_llama':
    command => 'git clone https://huggingface.co/TabbyML/CodeLlama-13B /opt/tabbyml/data/models/TabbyML/CodeLlama-13B',
    unless  => 'test -d /opt/tabbyml/data/models/TabbyML/CodeLlama-13B'
  }
  file {'/opt/tabbyml/nginx/htpasswd':
    ensure  => 'directory'
  }
  -> exec { 'htpasswd_tabby':
    command => "htpasswd -b -c /opt/tabbyml/nginx/htpasswd/${vhost} tabby ${vhost_password}",
    unless  => "test -f /opt/tabbyml/nginx/htpasswd/${vhost}",
  }
}
