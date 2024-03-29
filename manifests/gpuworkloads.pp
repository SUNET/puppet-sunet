# microk8s cluster node
class sunet::gpuworkloads(
  String $chatui_vhost  = 'chat.sunet.dev',
  String $interface     = 'enp2s0',
  String $localai_tag   = 'master-cublas-cuda12-ffmpeg',
  String $localai_vhost = 'localai-lab.sunet.se',
  String $tabby_model   = 'CodeLlama-13B',
  String $tabby_vhost   = 'tabby-lab.sunet.se',
  String $tabby_tag     = '0.9.0',
) {
  $localai_models = lookup('localai_models', undef, undef, [])
  $localai_vhost_password = lookup('localai_vhost_password')
  $repositories = lookup('tabby_repositories', undef, undef, [])
  $slack_app_token = lookup('slack_app_token')
  $slack_bot_token = lookup('slack_bot_token')
  $tabby_vhost_password = lookup('tabby_vhost_password')
  include sunet::packages::apache2_utils
  include sunet::packages::git
  include sunet::packages::git_lfs
  include sunet::packages::nvidia_container_toolkit
  include sunet::packages::nvidia_cuda_drivers
  include sunet::packages::wget
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
  -> exec { 'htpasswd_localai':
    command => "htpasswd -b -c /opt/gpuworkloads/nginx/htpasswd/${localai_vhost} localai ${localai_vhost_password}",
    unless  => "test -f /opt/gpuworkloads/nginx/htpasswd/${localai_vhost}",
  }
  file {'/opt/gpuworkloads/tabby':
    ensure  => 'directory'
  }
  file {'/opt/gpuworkloads/tabby-config.toml':
    ensure  => 'file',
    content => template('sunet/gpuworkloads/tabby-config.toml.erb'),
  }
  file {'/opt/gpuworkloads/localai':
    ensure  => 'directory'
  }
  file {'/opt/gpuworkloads/localai/gpt-3.5-turbo.yaml':
    ensure  => 'file',
    content => template('sunet/gpuworkloads/gpt-3.5-turbo.yaml.erb'),
  }
  $localai_models.each |$model| {
    $org = $model.split('/')[0]
    $repo = $model.split('/')[1]
    $model_name = $model.split('/')[2]
    $short_name = $model_name.split('\.')[0]
    $safe_name = $short_name.split('-').join('_')
    $defaultmpl = @(EOT)
      {{.Input}}
      ### Response:
      | EOT
    $tmpl = lookup("${safe_name}_tmpl", undef, undef, $defaultmpl)
    exec { "localai_model_${safe_name}":
      command => "wget -O /opt/gpuworkloads/localai/${short_name} https://huggingface.co/${org}/${repo}/resolve/main/${model_name}",
      unless  => "test -f /opt/gpuworkloads/localai/${short_name}"
    }
    -> file {"/opt/gpuworkloads/localai/${short_name}.tmpl":
      ensure  => 'file',
      content => inline_template($tmpl),
    }
  }
}
