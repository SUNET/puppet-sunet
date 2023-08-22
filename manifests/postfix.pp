# 389 ds class for SUNET
class sunet::postfix(
  String $domain = 'sunet.dev',
  String $interface = 'ens3',
  String $postfix_image  = 'docker.sunet.se/mail/postfix',
  String $postfix_tag    = '3.7.5-2-SUNET-1',
)
{
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
      port          =>  $port,
    }
  }
  file { '/opt/postfix/config':
    ensure => directory,
  }
  file { '/opt/postfix/config/main.cf':
    ensure  => file,
    content =>  template('sunet/postfix/main.erb.cf')
  }
  file { '/opt/postfix/config/master.cf':
    ensure  => file,
    content =>  template('sunet/postfix/master.erb.cf')
  }

}
