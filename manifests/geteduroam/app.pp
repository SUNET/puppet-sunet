# Get eduroam::app
class sunet::geteduroam::app(
  String $domain,
  String $realm,
  Hash $customers = {},
  Array $resolvers = [],
  String $app_tag = 'latest',
  String $haproxy_tag = '3.0.2',
  Array $app_admins = [],
  Boolean $qa_federation = false,
){

  class {'sunet::geteduroam::common': }

  ensure_resource('sunet::misc::create_dir', '/opt/geteduroam/var', { owner => 'root', group => 'www-data', mode => '0770'})

  # Ugly workaround since nunoc-ops install the class on all machines
  if $facts['networking']['fqdn'] != 'get-app-1.test.eduroam.se' {
    sunet::ici_ca::rp { 'infra': }
  }

  file {'/etc/ssl/private/infra.pem':
    ensure => 'link',
    target => "/etc/ssl/private/${facts['networking']['fqdn']}_infra.pem"
  }

  file {'/etc/ssl/private/infra.key':
    ensure => 'link',
    target => "/etc/ssl/private/${facts['networking']['fqdn']}_infra.key"
  }

  if lookup('saml_metadata_key', undef, undef, undef) != undef {
    sunet::snippets::secret_file { '/opt/geteduroam/cert/saml.key': hiera_key => 'saml_metadata_key', group =>  'www-data',  mode  => '0750', }
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
  sunet::nftables::allow { 'expose-allow-http':
    from => 'any',
    port => 80,
  }
  sunet::nftables::allow { 'expose-allow-https':
    from => 'any',
    port => 443,
  }

  sunet::docker_compose { 'geteduroam':
    content          => template('sunet/geteduroam/docker-compose-app.yml.erb'),
    service_name     => 'geteduroam',
    compose_dir      => '/opt/',
    compose_filename => 'docker-compose.yml',
    description      => 'geteduroam',
  }
}
