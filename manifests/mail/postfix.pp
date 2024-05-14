# Postfix for SUNET
class sunet::mail::postfix(
  String $domain                 = 'sunet.dev',
  String $smtp_domain            = 'sunet-smtp.drive.test.sunet.se',
  String $imap_domain            = 'sunet-imap.drive.test.sunet.se',
  String $environment            = 'test',
  String $interface              = 'ens3',
  String $postfix_image          = 'docker.sunet.se/mail/postfix',
  String $postfix_tag            = 'SUNET-1',
  Array[String] $relay_servers   = ['mf-tst-ng-1.sunet.se:587', 'mf-tst-ng-2.sunet.se:587'],
  Array[String] $imap_servers    = ['89.45.237.128', '89.46.21.203'],
)
{

  $hostname = $facts['networking']['fqdn']

  $config = lookup($environment)
  $db_hosts = join($config['db_hosts'], ' ')
  $relay_hosts = join($relay_servers, ', ')
  $nextcloud_db = 'nextcloud'
  $nextcloud_db_user ='nextcloud'
  $nextcloud_mysql_password = lookup('nextcloud_mysql_password')

  $smtpd_tls_cert_file="/certs/${smtp_domain}/fullchain.pem"
  $smtpd_tls_key_file="/certs/${smtp_domain}/privkey.pem"

  package { 'exim4-base':
    ensure => absent,
    provider => 'apt',
  }


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
    'mysql-virtual-mailbox-domains',
    'mysql-virtual-mailbox-maps'
  ]
  $config_files.each |$file| {
    file { "/opt/postfix/config/${file}.cf":
      ensure  => file,
      content =>  template("sunet/mail/postfix/${file}.erb.cf")
    }
  }

  service { 'postfix':
    ensure => 'stopped',
  }

}
