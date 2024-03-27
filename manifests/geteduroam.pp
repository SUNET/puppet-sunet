# Get eduroam
class sunet::geteduroam(
  String $domain,
  String $realm,
  Array $resolvers = [],
  Boolean $mariadb = true,
  String $mariadb_host = $facts['ipaddress_default'],
  Boolean $app = true,
  Boolean $radius = true,
  Boolean $ocsp = true,
  String $app_tag = 'latest',
  String $freeradius_tag = 'latest',
  String $ocsp_tag = 'latest',
  Array $app_admins = [],
  Array $required_scoped_affiliation = [],
  Boolean $qa_federation = false,
){

  ensure_resource('sunet::misc::create_dir', '/opt/geteduroam/config', { owner => 'root', group => 'root', mode => '0750'})
  ensure_resource('sunet::misc::create_dir', '/opt/geteduroam/cert', { owner => 'root', group => 'root', mode => '0755'})

  if $mariadb {
    sunet::mariadb { 'geteduroam_db':
    }
  }

  if $radius {
    sunet::nftables::allow { 'expose-allow-radius':
      from  => lookup('radius_servers', undef, undef,['192.36.171.226', '192.36.171.227', '2001:6b0:8:2::226', '2001:6b0:8:2::227'] ),
      port  => 1812,
      proto =>  'udp'
    }

    file { '/etc/letsencrypt/renewal-hooks/deploy/geteduroam':
      ensure  => file,
      mode    => '0700',
      content => file('sunet/geteduroam/certbot-renewal-hook'),
    }

    $shared_secret = lookup('shared_secret', undef, undef, undef)
    file { '/opt/geteduroam/config/clients.conf':
      content => template('sunet/geteduroam/clients.conf.erb'),
      mode    => '0755',
    }
  }
  if $app {
    ensure_resource('sunet::misc::create_dir', '/opt/geteduroam/var', { owner => 'root', group => 'www-data', mode => '0770'})

    if lookup('saml_metadata_key', undef, undef, undef) != undef {
      sunet::snippets::secret_file { '/opt/geteduroam/cert/saml.key': hiera_key => 'saml_metadata_key' }
      # assume cert is in cosmos repo
    } else {
      # make key pair
      sunet::snippets::keygen {'saml_metadata_key':
        key_file  => '/opt/geteduroam/cert/saml.key',
        cert_file => '/opt/geteduroam/cert/saml.pem',
      }
    }

    file { '/opt/geteduroam/config/letswifi.conf.php':
      content => template('sunet/geteduroam/letswifi.conf.simplesaml.php.erb'),
      mode    => '0755',
    }
    file { '/opt/geteduroam/config/config.php':
      content => template('sunet/geteduroam/config.php.erb'),
      mode    => '0755',
    }
    file { '/opt/geteduroam/config/authsources.php':
      content => template('sunet/geteduroam/authsources.php.erb'),
      mode    => '0755',
    }

    if $qa_federation {
      file { '/opt/geteduroam/cert/swamid.crt':
        content => file('sunet/geteduroam/swamid-qa.crt'),
        mode    => '0755',
        }
    } else {
      file { '/opt/geteduroam/cert/swamid.crt':
        content => file('sunet/geteduroam/md-signer2.crt'),
        mode    => '0755',
        }
    }
    file { '/opt/geteduroam/cert/saml.key':
      group =>  'www-data',
      mode  => '0750',
    }
    sunet::nftables::allow { 'expose-allow-http':
      from => 'any',
      port => 80,
    }
    sunet::nftables::allow { 'expose-allow-https':
      from => 'any',
      port => 443,
    }
    class { 'sunet::dehydrated::client': domain =>  $domain, ssl_links => true }
  }

  if $ocsp {
      file { '/opt/geteduroam/config/eap.conf':
        content => template('sunet/geteduroam/eap.conf.erb'),
        mode    => '0755',
        }

  }

  sunet::docker_compose { 'geteduroam':
    content          => template('sunet/geteduroam/docker-compose.yml.erb'),
    service_name     => 'geteduroam',
    compose_dir      => '/opt/',
    compose_filename => 'docker-compose.yml',
    description      => 'geteduroam',
  }

}
