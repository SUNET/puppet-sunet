# Postfix for SUNET
class sunet::mail::postfix(
  String $domain                 = 'sunet.dev',
  String $interface              = 'ens3',
  String $postfix_image          = 'docker.sunet.se/mail/postfix',
  String $postfix_tag            = 'SUNET-1',
  Array[String] $relay_servers   = ['mf-tst-ng-1.sunet.se:587', 'mf-tst-ng-2.sunet.se:587'],
  Array[String] $webfronts       = ['192.121.208.200', '89.45.237.97', '89.46.21.22'],
)
{

  $hostname = $facts['networking']['fqdn']
  # This looks esoteric, a longer example for parsing the hostname is available here:
  # https://wiki.sunet.se/display/sunetops/Platform+naming+standards#Platformnamingstandards-Parsingthename
  $my_environment = split(split($hostname, '[.]')[0],'[-]')[2]

  $config = lookup($my_environment)
  $db_hosts = join($config['db_hosts'], ' ')
  $relay_hosts = join($relay_servers, ', ')
  $nextcloud_db = 'nextcloud'
  $nextcloud_db_user ='nextcloud'
  $nextcloud_mysql_password = lookup('nextcloud_mysql_password')

  $smtpd_tls_cert_file="/certs/smtp.${domain}/fullchain.pem"
  $smtpd_tls_key_file="/certs/smtp.${domain}/privkey.pem"
  # Composefile
  sunet::docker_compose { 'postfix':
    content          => template('sunet/mail/postfix/docker-compose.erb.yml'),
    service_name     => 'postfix',
    compose_dir      => '/opt',
    compose_filename => 'docker-compose.yml',
    description      => 'Postfix',
  }
  $ports = [25, 80, 587]
  $ports.each|$port| {
    sunet::nftables::docker_expose { "mail_port_${port}":
      allow_clients => 'any',
      port          => $port,
      iif           => $interface,
    }
  }
  file { '/opt/postfix/config':
    ensure => directory,
  }
  $config_files = [
    'main',
    'master',
    'mysql-virtual-email2email',
    'mysql-virtual-mailbox-domains',
    'mysql-virtual-mailbox-maps'
  ]
  $config_files.each |$file| {
    file { "/opt/postfix/config/${file}.cf":
      ensure  => file,
      content =>  template("sunet/mail/postfix/${file}.erb.cf")
    }
  }

}
