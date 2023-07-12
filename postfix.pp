# 389 ds class for SUNET
class sunet::postfix(
  Array[String] $client_ips,
  String $interface = 'ens3',
  String $dir_admin_username = 'admin',
  String $postfix_image  = 'quay.io/389ds/dirsrv',
  String $postfix_tag    = 'c9s',
)
{
  $hostname = $facts['networking']['fqdn']
  # Composefile
  sunet::docker_compose { 'postfix':
    content          => template('sunet/postfix/docker-compose.erb.yml'),
    service_name     => 'postfix',
    compose_dir      => '/opt',
    compose_filename => 'docker-compose.yml',
    description      => 'Postfix',
  }
  $ports = []
  $ports.each|$port| {
    sunet::nftables::docker_expose { "mail_port_${port}":
      allow_clients => $client_ips,
      port          =>  $port,
    }
  }
  file { '/opt/postfix/config':
    ensure => directory,
  }

}
