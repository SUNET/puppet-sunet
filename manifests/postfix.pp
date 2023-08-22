# 389 ds class for SUNET
class sunet::postfix(
  String $domain = 'sunet.dev',
  String $interface = 'ens3',
  String $postfix_image  = 'docker.sunet.se/mail/postfix',
  String $postfix_tag    = 'SUNET-1',
  String $db_host        = 'internal-sto3-test-mail-1.mail.sunet.se',
)
{
  $db_password = safe_hiera('db_password')
  $hostname = $facts['networking']['fqdn']
  # FIXME: Use acme certs
  $smtpd_tls_cert_file='/etc/ssl/certs/ssl-cert-snakeoil.pem'
  $smtpd_tls_key_file='/etc/ssl/private/ssl-cert-snakeoil.key'
  # Composefile
  sunet::docker_compose { 'postfix':
    content          => template('sunet/postfix/docker-compose.erb.yml'),
    service_name     => 'postfix',
    compose_dir      => '/opt',
    compose_filename => 'docker-compose.yml',
    description      => 'Postfix',
  }
  $ports = [25, 587]
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
    'mysql-virtual-alias-maps',
    'mysql-virtual-email2email',
    'mysql-virtual-mailbox-domains',
    'mysql-virtual-mailbox-maps'
  ]
  $config_files.each |$file| {
    file { "/opt/postfix/config/${file}.cf":
      ensure  => file,
      content =>  template("sunet/postfix/${file}.erb.cf")
    }
  }

}
