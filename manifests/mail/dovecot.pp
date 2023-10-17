# Dovecot for SUNET mail
class sunet::mail::dovecot(
  String $replication_partner,
  Array[String] $allow_nets      = [
                                    '192.121.208.200/32',
                                    '2a0a:bcc0:40::59c/128',
                                    '89.45.237.97/32',
                                    '2001:6b0:40::2e3/128',
                                    '89.46.21.22/32',
                                    '2001:6b0:6c::33d/128',
                                    '89.46.20.7/32',
                                    '2001:6b0:6c::267/128',
                                    '89.46.20.211/32',
                                    '2001:6b0:6c::326/128',
                                    '89.46.21.198/32',
                                    '2001:6b0:6c::402/128'
                                  ],
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
  $oauth_client_id = lookup('oauth_client_id')
  $oauth_client_secret = lookup('oauth_client_secret')


  $nextcloud_salt = lookup('nextcloud_salt')
  $nextcloud_db = 'nextcloud'
  $nextcloud_db_user ='nextcloud'
  $nextcloud_mysql_password = lookup('nextcloud_mysql_password')
  $nextcloud_mysql_server = 'intern-db1.sunet.drive.test.sunet.se'


  $ssl_cert="/certs/imap.${domain}/fullchain.pem"
  $ssl_key="/certs/imap.${domain}/privkey.pem"
  # Composefile
  sunet::docker_compose { 'dovecot':
    content          => template('sunet/mail/dovecot/docker-compose.erb.yml'),
    service_name     => 'dovecot',
    compose_dir      => '/opt',
    compose_filename => 'docker-compose.yml',
    description      => 'Dovecot',
  }
  $ports = [24, 80, 143, 993, 12345, 12346]
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
    'dovecot-oauth2',
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

  $commands = ['doveadm', 'doveconf', 'dovecot', 'dovecot-sysreport']
  $commands.each |$command| {
    file { "/usr/local/bin/${command}":
      ensure  => file,
      content =>  inline_template("#!/bin/bash\ndocker exec -ti dovecot_dovecot_1 ${command} \"\${@}\"\n"),
      mode    => '0700',
    }
  }

}
