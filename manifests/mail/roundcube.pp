# Postfix for SUNET
class sunet::mail::roundcube(
  String $domain,
  String $carddav_plugin_url      = 'https://github.com/mstilkerich/rcmcarddav/releases/download/v5.1.0/carddav-v5.1.0.tar.gz',
  String $custom_links_plugin_url = 'https://gitlab.com/MatthiasLohr/roundcube-custom-links/-/archive/main/roundcube-custom-links-main.tar.gz',
  String $imap_host               = "mail.${domain}",
  String $interface               = 'ens3',
  String $mariadb_host            = lookup('mariadb_host', undef, undef, undef),
  String $roundcube_image         = 'docker.sunet.se/mail/roundcube',
  String $roundcube_tag           = '1.6.9-apache-1',
  String $shib_plugin_url         = 'https://gitlab.mpi-klsb.mpg.de/pcernko/shib_auth/-/archive/master/shib_auth-master.tar.gz',
  String $smtp_host               = "mail.${domain}",
)
{

  # Composefile
  sunet::docker_compose { 'roundcube':
    content          => template('sunet/mail/roundcube/docker-compose.erb.yml'),
    service_name     => 'roundcube',
    compose_dir      => '/opt',
    compose_filename => 'docker-compose.yml',
    description      => 'Roundcube',
  }
  $open_ports = [80, 443]
  $open_ports.each|$port| {
    sunet::nftables::docker_expose { "mail_port_${port}":
      allow_clients => 'any',
      port          => $port,
      iif           => $interface,
    }
  }
  # config
  $mariadb_password = lookup('mariadb_password', undef, undef, undef)
  $master_password = lookup('master_password', undef, undef, undef)
  $mariadb_user = 'roundcube'
  $cert_dir = '/opt/roundcube/certs'
  $conf_dir = '/opt/roundcube/config'
  $plugin_dir = '/opt/roundcube/plugins'
  file { [$cert_dir, $conf_dir, $plugin_dir]:
    ensure => directory,
  }
  if lookup('shib_key', undef, undef, undef) != undef {
    sunet::snippets::secret_file { "${cert_dir}/sp-cert.key": hiera_key => 'shib_key' }
    # assume cert is in cosmos repo
  } else {
    # make key pair
    sunet::snippets::keygen {'shib_key':
      key_file  => "${cert_dir}/sp-cert.key",
      cert_file => "${cert_dir}/sp-cert.pem"
    }
  }
  file { '/opt/roundcube/config/config.inc.php':
    ensure  => file,
    content =>  template('sunet/mail/roundcube/config.inc.erb.php')
  }
  exec { 'shib-plugin-install':
    command => "wget ${shib_plugin_url} -O /tmp/shib.tgz && \
    tar -xzf /tmp/shib.tgz -C /tmp && mv /tmp/shib_auth-master \
    ${plugin_dir}/shib_auth && rm /tmp/shib.tgz",
    unless  => 'test -d /opt/roundcube/plugins/shib_auth',
  }
  exec { 'carddav-plugin-install':
    command => "wget ${carddav_plugin_url} -O /tmp/carddav.tgz && \
    tar -xzf /tmp/carddav.tgz -C /tmp && mv /tmp/carddav \
    ${plugin_dir}/carddav && rm /tmp/carddav.tgz",
    unless  => 'test -d /opt/roundcube/plugins/carddav',
  }
  exec {'custom-links-plugin-install':
    command => "wget ${custom_links_plugin_url} -O /tmp/custom_links.tgz && \
    tar -xzf /tmp/custom_links.tgz -C /tmp && mv /tmp/roundcube-custom-links-main \
    ${plugin_dir}/custom_links && rm /tmp/custom_links.tgz",
    unless  => 'test -d /opt/roundcube/plugins/custom_links',
  }
}
