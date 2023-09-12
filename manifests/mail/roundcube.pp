# Postfix for SUNET
class sunet::mail::roundcube(
  String $domain                 = 'sunet.dev',
  String $interface              = 'ens3',
  String $roundcube_image          = 'roundcube/roundcubemail',
  String $roundcube_tag            = '1.6.2-apache',
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

  $roundcube_password = lookup('roundcube_password')
  $des_key = lookup('des_key')
  $oauth_client_id = lookup('oauth_client_id')
  $oauth_client_secret = lookup('oauth_client_secret')

  # Composefile
  sunet::docker_compose { 'roundcube':
    content          => template('sunet/mail/roundcube/docker-compose.erb.yml'),
    service_name     => 'roundcube',
    compose_dir      => '/opt',
    compose_filename => 'docker-compose.yml',
    description      => 'roundcube',
  }
  $ports = [80, 443]
  $ports.each|$port| {
    sunet::nftables::docker_expose { "mail_port_${port}":
      allow_clients => 'any',
      port          => $port,
      iif           => $interface,
    }
  }
  file { '/opt/roundcube/config':
    ensure => directory,
  }
  file { '/opt/roundcube/config/config.inc.php':
    ensure  => file,
    content =>  template('sunet/mail/roundcube/config.inc.erb.php')
  }

}
