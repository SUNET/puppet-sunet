# Run bankid-idp with compose
class sunet::bankidp(
  String $instance,
  Array $environments_extras = [],
  Array $ports_extras = [],
  Array $resolvers = [],
  Array $volumes_extras = [],
  Boolean $app_node = false,
  Boolean $prod = true,
  Boolean $redis_node = false,
  String $bankid_home = '/opt/bankidp',
  String $imagetag='latest',
  String $interface = 'ens3',
  String $service_name = 'bankidp.qa.swamid.se',
  String $spring_config_import = '/config/bankidp.yml',
  String $tz = 'Europe/Stockholm',
) {

  $apps = $facts['bankid_cluster_info']['apps']
  $redises = $facts['bankid_cluster_info']['redises']

  sunet::ici_ca::rp { 'infra': }

  if $app_node {

    sunet::nftables::docker_expose { 'https' :
      iif           => $interface,
      allow_clients => 'any',
      port          => 443,
    }

    $credsdir = "${bankid_home}/credentials"
    # Unwanted password - but hey Java!
    $pass = 'qwerty123'

    ensure_resource('sunet::misc::create_dir', $credsdir, { owner => 'root', group => 'root', mode => '0750'})
    $customers = lookup('bankidp_customers', undef, undef, undef)
    sort(keys($customers)).each |$name| {
      sunet::snippets::secret_file { "${credsdir}/${name}.key": hiera_key => "bankidp_customers.${name}.key" }
      $password = lookup("bankidp_customers.${name}.password", undef, undef, undef)
      exec { "build_${name}.p12":
        command => "openssl pkcs12 -export -in ${credsdir}/${name}.pem -inkey ${credsdir}/${name}.key -name '${name}-bankid' -out ${credsdir}/${name}.p12 -passin pass:${password} -passout pass:${pass}",
        onlyif  => "test ! -f ${credsdir}/${name}.p12"
      }
    }

    if lookup('bankid_saml_metadata_key', undef, undef, undef) != undef {
      sunet::snippets::secret_file { "${credsdir}/metadata.key": hiera_key => 'bankid_saml_metadata_key' }
      # assume cert is in cosmos repo
    } else {
      # make key pair
      sunet::snippets::keygen {'bankid_saml_metadata_key':
        key_file  => "${credsdir}/saml_metadata.key",
        cert_file => "${credsdir}/saml_metadata.pem"
      }
    }
    exec { 'saml_metadata.p12':
      command => "openssl pkcs12 -export -in ${credsdir}/saml_metadata.pem -inkey ${credsdir}/saml_metadata.key -name 'saml_metadata' -out ${credsdir}/saml_metadata.p12 -passout pass:${pass}",
      onlyif  => "test ! -f ${credsdir}/saml_metadata.p12"
    }

    package {'openjdk-17-jre-headless':
      ensure => latest
    }

    exec { 'infra.p12':
      command => "keytool -import -noprompt -deststorepass ${pass} -file /etc/ssl/certs/infra.crt -keystore /etc/ssl/certs/infra.p12",
      onlyif  => 'test ! -f /etc/ssl/certs/infra.p12'
    }

    exec { "${facts['networking']['fqdn']}_infra.p12":
      command => "openssl pkcs12 -export -in /etc/ssl/certs/${facts['networking']['fqdn']}_infra.crt -inkey /etc/ssl/private/${facts['networking']['fqdn']}_infra.pem -name 'infra' -out /etc/ssl/private/${facts['networking']['fqdn']}_infra.p12 -passout pass:${pass}",
      onlyif  => "test ! -f /etc/ssl/private/${facts['networking']['fqdn']}_infra.p12"
    }

    class { 'sunet::frontend::register_sites':
      sites => {
        $service_name => {
          frontends => ['se-fre-lb-1.sunet.se', 'se-tug-lb-1.sunet.se'],
          port      => '443',
        }
      }
    }
    ensure_resource('sunet::misc::create_dir', '/opt/bankidp/config/', { owner => 'root', group => 'root', mode => '0750'})
    file { '/opt/bankidp/config/bankidp.yml':
      content => template('sunet/bankidp/bankidp.yml.erb'),
      mode    => '0755',
    }

    $signing_cert = $prod ? {
      true => 'md-signer2.crt',
      false => 'swamid-qa.crt',
    }

    file { "/opt/bankidp/credentials/${signing_cert}":
      ensure  => 'file',
      mode    => '0755',
      owner   => 'root',
      content => file("sunet/bankidp/${signing_cert}")
    }

    $resourcedir = "${bankid_home}/resources"
    ensure_resource('sunet::misc::create_dir', $resourcedir, { owner => 'root', group => 'root', mode => '0750'})
    file { "${resourcedir}/sunet.svg":
      ensure  => 'file',
      mode    => '0755',
      owner   => 'root',
      content => file('sunet/bankidp/sunet.svg')
    }

    sunet::docker_compose { 'bankidp':
      content          => template('sunet/bankidp/docker-compose-bankid-idp.yml.erb'),
      service_name     => 'bankidp',
      compose_dir      => '/opt/',
      compose_filename => 'docker-compose.yml',
      description      => 'Freja ftw',
    }
  }
  if $redis_node {
    class { 'sunet::rediscluster':
      numnodes => 2,
      hostmode => true,
      tls      => true
    }
  }
}
