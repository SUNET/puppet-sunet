# Dovecot for SUNET mail
class sunet::mail::dovecot(
  String $replication_partner,
  String $domain                 = 'sunet.dev',
  String $interface              = 'ens3',
  String $dovecot_image          = 'docker.sunet.se/mail/dovecot',
  String $dovecot_tag            = 'SUNET-1',
)
{

  $hostname = $facts['networking']['fqdn']
  # This looks esoteric, a longer example for parsing the hostname is available here:
  # https://wiki.sunet.se/display/sunetops/Platform+naming+standards#Platformnamingstandards-Parsingthename
  $my_environment = split(split($hostname, '[.]')[0],'[-]')[2]

  $config = lookup($my_environment)
  $db_hosts = join($config['db_hosts'], ' host=')

  $db_password = lookup('db_password')
  $replication_password = lookup('replication_password')


  # FIXME: Use acme certs
  $ssl_cert='/etc/ssl/certs/ssl-cert-snakeoil.pem'
  $ssl_key='/etc/ssl/private/ssl-cert-snakeoil.key'
  # Composefile
  sunet::docker_compose { 'dovecot':
    content          => template('sunet/mail/dovecot/docker-compose.erb.yml'),
    service_name     => 'dovecot',
    compose_dir      => '/opt',
    compose_filename => 'docker-compose.yml',
    description      => 'Dovecot',
  }
  $ports = [24, 80, 143, 993, 12345]
  $ports.each|$port| {
    sunet::nftables::docker_expose { "mail_port_${port}":
      allow_clients => 'any',
      port          => $port,
      iif           => $interface,
    }
  }
  file { '/opt/dovecot/mail':
    ensure => directory,
    owner  => 'mail',
    group  => 'mail',
  }
  file { '/opt/dovecot/mail/vhosts':
    ensure => directory,
    owner  => 'mail',
    group  => 'mail',
  }
  file { "/opt/dovecot/mail/${domain}":
    ensure => directory,
    owner  => 'mail',
    group  => 'mail',
  }
  file { '/opt/dovecot/config':
    ensure => directory,
  }
  $config_files = [
    'dovecot',
    'dovecot-sql',
  ]
  $config_files.each |$file| {
    file { "/opt/dovecot/config/${file}.conf":
      ensure  => file,
      content =>  template("sunet/mail/dovecot/${file}.erb.conf")
    }
  }
  $commands = ['doveadm', 'doveconf', 'dovecot', 'dovecot-sysreport']
  $commands.each |$command| {
    file { "/usr/local/bin/${command}":
      ensure  => file,
      content =>  inline_template("#!/bin/bash\ndocker exec -ti dovecot_dovecot_1 ${command} \"\${@}\"\n"),
      mode    => '0700',
    }
  }

}
