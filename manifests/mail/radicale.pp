# Postfix for SUNET
class sunet::mail::radicale(
  String $domain,
  Integer $auth_port     = 12346,
  Integer $port          = 5232,
  String $auth_host      = "mail.${domain}",
  String $cal_domain     = "calendar.${domain}",
  String $interface      = 'ens3',
  String $mariadb_host   = lookup('mariadb_host', undef, undef, undef),
  String $radicale_image = 'docker.sunet.se/mail/radicale',
  String $radicale_tag   = '3.1.8-1',
)
{
  # Composefile
  sunet::docker_compose { 'radicale':
    content          => template('sunet/mail/radicale/docker-compose.erb.yml'),
    service_name     => 'radicale',
    compose_dir      => '/opt',
    compose_filename => 'docker-compose.yml',
    description      => 'Radicale',
  }
  $open_ports = [$port]
  $open_ports.each|$port| {
    sunet::nftables::docker_expose { "radicale_port_${port}":
      allow_clients => 'any',
      port          => $port,
      iif           => $interface,
    }
  }
  $mariadb_password = lookup('mariadb_password', undef, undef, undef)
  $mariadb_user = 'radicale'
  $db_url="mysql://${mariadb_user}:${mariadb_password}@${mariadb_host}/radicale"
  $conf_dir = '/opt/radicale/config'
  file { [$conf_dir]:
    ensure => directory,
  }
  file { '/opt/radicale/config/default.conf':
    ensure  => file,
    content =>  template('sunet/mail/radicale/default.erb.conf')
  }
}
