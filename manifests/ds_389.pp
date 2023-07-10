# 389 ds class for SUNET
class sunet::ds_389(
  Array[String] $client_ips,
  String $dir_suffix,
  String $interface = 'ens3',
  String $dir_admin_username = 'admin',
  String $ds_image  = '389ds/dirserver',
  String $ds_tag    = '2.4',
)
{
  $hostname = $facts['networking']['fqdn']
  $dir_manager_password = lookup('dir_manager_password')
  # Composefile
  sunet::docker_compose { '389_ds':
    content          => template('sunet/ds_389/docker-compose.erb.yml'),
    service_name     => 'ds_389',
    compose_dir      => '/opt',
    compose_filename => 'docker-compose.yml',
    description      => '389 DS',
  }
  $ports = [389, 636]
  $ports.each|$port| {
    sunet::nftables::docker_expose { "ldap_port_${port}":
      allow_clients => $client_ips,
      port          =>  $port,
    }
  }
  $directories = ['data', 'config', 'logs', 'certs']
  $directories.each|$dir| {
    file { "/opt/ds_389/${dir}":
      ensure => directory,
    }
  }

}
