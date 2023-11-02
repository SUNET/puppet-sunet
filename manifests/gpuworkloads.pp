# microk8s cluster node
class sunet::gpuworkloads(
  String $interface   = 'enp2s0',
  String $tabby_model = 'CodeLlama-13B',
  String $tabby_vhost       = 'tabby-lab.sunet.se',
  String $localai_vhost       = 'localai-lab.sunet.se',
  String $localai_tag       = 'v1.40.0-cublas-cuda12-ffmpeg',
) {
  $tabby_vhost_password = lookup('tabby_vhost_password')
  $localai_vhost_password = lookup('localai_vhost_password')
  $repositories = lookup('tabby_repositories', undef, undef, [])
  include sunet::packages::apache2_utils
  include sunet::packages::git
  include sunet::packages::git_lfs
  include sunet::packages::nvidia_container_toolkit
  include sunet::packages::nvidia_cuda_drivers
  sunet::docker_compose { 'gpuworkloads':
    content          => template('sunet/gpuworkloads/docker-compose.yml.erb'),
    service_name     => 'gpuworkloads',
    compose_dir      => '/opt',
    compose_filename => 'docker-compose.yml',
    description      => 'GPU Workloads',
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
    command => 'git clone https://huggingface.co/TabbyML/CodeLlama-13B /opt/gpuworkloads/tabby/models/TabbyML/CodeLlama-13B',
    unless  => 'test -d /opt/gpuworkloads/tabby/models/TabbyML/CodeLlama-13B'
  }
  file {'/opt/gpuworkloads/nginx/htpasswd':
    ensure  => 'directory'
  }
  -> exec { 'htpasswd_tabby':
    command => "htpasswd -b -c /opt/gpuworkloads/nginx/htpasswd/${tabby_vhost} tabby ${tabby_vhost_password}",
    unless  => "test -f /opt/gpuworkloads/nginx/htpasswd/${tabby_vhost}",
  }
  file {'/opt/gpuworkloads/tabby':
    ensure  => 'directory'
  }
  file {'/opt/gpuworkloads/tabby-config.toml':
    ensure  => 'file',
    content => template('sunet/gpuworkloads/tabby-config.toml.erb'),
  }
}
