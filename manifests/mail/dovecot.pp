# Dovecot for SUNET mail
class sunet::mail::dovecot(
  String $replication_partner,
  Array[String] $allow_nets,
  String $domain,
  String $imap_domain,
  String $environment,
  String $account_domain         = 'sunet.se',
  String $interface              = 'ens3',
  String $dovecot_image          = 'docker.sunet.se/mail/dovecot',
  String $dovecot_tag            = 'SUNET-1',
)
{
  include sunet::packages::xfsprogs # for /opt/dovecot/mail

  $hostname = $facts['networking']['fqdn']

  $config = lookup($environment)

  $replication_password = lookup('replication_password')
  $master_password = lookup('master_password')


  $db_hosts = join($config['db_hosts'], ' host=')
  ## FIXME: This is NOT what Nextcloud calls 'salt', but instead what they call 'secret'.
  $nextcloud_salt = lookup('nextcloud_salt')
  $nextcloud_db = 'nextcloud'
  $nextcloud_db_user ='nextcloud'
  $nextcloud_mysql_password = lookup('nextcloud_mysql_password')
  $nextcloud_mysql_server = $config['nextcloud_mysql_server']


  $ssl_cert="/certs/${imap_domain}/fullchain.pem"
  $ssl_key="/certs/${imap_domain}/privkey.pem"
  # Composefile
  sunet::docker_compose { 'dovecot':
    content          => template('sunet/mail/dovecot/docker-compose.erb.yml'),
    service_name     => 'dovecot',
    compose_dir      => '/opt',
    compose_filename => 'docker-compose.yml',
    description      => 'Dovecot',
  }
  $ports = [24, 143, 465, 993, 4190, 12345, 12346]
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
    ensure => absent,
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
  file { '/opt/dovecot/config/nextcloud-auth.lua':
    ensure  => file,
    content =>  template('sunet/mail/dovecot/nextcloud-auth.erb.lua')
  }
  file { '/opt/dovecot/config/ssmtp.conf':
    ensure  => file,
    content => template('sunet/mail/dovecot/ssmtp.erb.conf'),
  }

  $commands = ['doveadm', 'doveconf', 'dovecot', 'dovecot-sysreport']
  $commands.each |$command| {
    file { "/usr/local/bin/${command}":
      ensure  => file,
      content =>  inline_template("#!/bin/bash\ndocker exec -ti dovecot-dovecot-1 ${command} \"\${@}\"\n"),
      mode    => '0700',
    }
  }

}
