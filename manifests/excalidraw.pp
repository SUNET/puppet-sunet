# mastodon web server
class sunet::mastodon::web(
  String $vhost                    = 'social.sunet.se',
) {
  # Must set in hiera eyaml
  $vapid_private_key=safe_hiera('vapid_private_key')

  # Interpolated variables
  # Composefile
  sunet::docker_compose { 'excalidraw':
    content          => template('sunet/excalidraw/docker-compose.yml.erb'),
    service_name     => 'excalidraw',
    compose_dir      => '/opt',
    compose_filename => 'docker-compose.yml',
    description      => 'Excalidraw',
  }
  $tl_dirs = ['excalidraw', 'nginx']
  $tl_dirs.each | $dir| {
    file { "/opt/excalidraw/${dir}":
      ensure => directory,
      owner  => 'root',
      group  => 'root',
      mode   => '0751',
    }
  }
  $nginx_dirs = ['acme', 'certs', 'conf', 'dhparam', 'html', 'vhost']
  $nginx_dirs.each | $dir| {
    file { "/opt/mastodon_web/nginx/${dir}":
      ensure => directory,
      owner  => 'root',
      group  => 'root',
      mode   => '0751',
    }
  }

  if $::facts['sunet_nftables_enabled'] == 'yes' {
    sunet::nftables::docker_expose { 'web_http_port' :
      iif           => $interface,
      allow_clients => 'any',
      port          => 80,
    }
    sunet::nftables::docker_expose { 'web_https_port' :
      iif           => $interface,
      allow_clients => 'any',
      port          => 443,
    }
  } else {
    sunet::misc::ufw_allow { 'web_ports':
      from => 'any',
      port => ['80', '443']
    }
  }
}
