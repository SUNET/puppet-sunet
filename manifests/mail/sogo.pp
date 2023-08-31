# Postfix for SUNET
class sunet::mail::sogo(
  String $domain                 = 'sunet.dev',
  String $interface              = 'ens3',
  String $sogo_image          = 'docker.sunet.se/mail/sogo',
  String $sogo_tag            = 'SUNET-1',
)
{

  $hostname = $facts['networking']['fqdn']
  # This looks esoteric, a longer example for parsing the hostname is available here:
  # https://wiki.sunet.se/display/sunetops/Platform+naming+standards#Platformnamingstandards-Parsingthename
  $my_environment = split(split($hostname, '[.]')[0],'[-]')[2]

  $config = lookup($my_environment)
  $db_hosts = $config['db_hosts']
  $db_ips = $db_hosts.map |$host| {
    $addrs = dns_lookup($host)
    $addrs[0]
  }

  $db_password = lookup('db_password')


  $ssl_cert="/certs/mail.${domain}.crt"
  $ssl_key="/certs/mail.${domain}.key"
  # Composefile
  sunet::docker_compose { 'sogo':
    content          => template('sunet/mail/sogo/docker-compose.erb.yml'),
    service_name     => 'sogo',
    compose_dir      => '/opt',
    compose_filename => 'docker-compose.yml',
    description      => 'sogo',
  }
  $ports = [80, 443]
  $ports.each|$port| {
    sunet::nftables::docker_expose { "mail_port_${port}":
      allow_clients => 'any',
      port          => $port,
      iif           => $interface,
    }
  }
  file { '/opt/sogo/config':
    ensure => directory,
  }
  $config_files = [
    'sogo',
  ]
  $config_files.each |$file| {
    file { "/opt/sogo/config/${file}.conf":
      ensure  => file,
      content =>  template("sunet/mail/sogo/${file}.erb.conf")
    }
  }

}
