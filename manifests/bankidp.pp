# Run bankid-idp with compose
class sunet::bankidp(
  String $instance,
  Array $environments_extras = [],
  Array $ports_extras = [],
  Array $resolvers = [],
  Array $volumes_extras = [],
  Boolean $swamid = true,
  Boolean $swedenconnect = false,
  Boolean $app_node = false,
  Boolean $prod = true,
  Boolean $redis_node = false,
  Boolean $infra_cert_from_this_class = true,
  String $bankid_home = '/opt/bankidp',
  String $imagetag='latest',
  String $interface = 'ens3',
  String $service_name = 'bankidp.qa.swamid.se',
  String $service_path = '/bankid/idp',
  String $spring_config_import = '/config/bankidp.yml',
  String $tz = 'Europe/Stockholm',
) {

  $apps = $facts['bankid_cluster_info']['apps']
  $redises = $facts['bankid_cluster_info']['redises']

  if $infra_cert_from_this_class {
    sunet::ici_ca::rp { 'infra': }
  }

  if $app_node {

    $base_url_and_entity_id = "https://${service_name}${service_path}"

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
        command => "openssl pkcs12 -export -in '${credsdir}/${name}.pem' -inkey '${credsdir}/${name}.key' -name '${name}-bankid' -out '${credsdir}/${name}.p12' -passin pass:'${password}' -passout pass:'${pass}'",
        onlyif  => "test ! -f ${credsdir}/${name}.p12"
      }
    }

    if lookup('bankid_saml_metadata_key', undef, undef, undef) != undef {
      sunet::snippets::secret_file { "${credsdir}/saml_metadata.key": hiera_key => 'bankid_saml_metadata_key' }
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
          frontends => ['sthb-lb-1.sunet.se', 'tug-lb-1.sunet.se'],
          port      => '443',
        }
      }
    }
    ensure_resource('sunet::misc::create_dir', '/opt/bankidp/config/', { owner => 'root', group => 'root', mode => '0750'})
    file { '/opt/bankidp/config/bankidp.yml':
      content => template('sunet/bankidp/bankidp.yml.erb'),
      mode    => '0755',
    }



    if $swamid {
      $swamid_signing_cert = $prod ? {
        true => 'md-signer2.crt',
        false => 'swamid-qa.crt',
      }

      file { "/opt/bankidp/credentials/${swamid_signing_cert}":
        ensure  => 'file',
        mode    => '0755',
        owner   => 'root',
        content => file("sunet/bankidp/${swamid_signing_cert}")
      }
    }

    if $swedenconnect {
      $sc_signing_cert = $prod ? {
        true => 'swedenconnect.se.cert',
        false => 'qa.swedenconnect.se.cert',
      }

      file { "/opt/bankidp/credentials/${sc_signing_cert}":
        ensure  => 'file',
        mode    => '0755',
        owner   => 'root',
        content => file("sunet/bankidp/${sc_signing_cert}")
      }
    }

    $resourcedir = "${bankid_home}/resources"
    ensure_resource('sunet::misc::create_dir', $resourcedir, { owner => 'root', group => 'root', mode => '0750'})
    file { "${resourcedir}/sunet.svg":
      ensure  => 'file',
      mode    => '0755',
      owner   => 'root',
      content => file('sunet/bankidp/sunet.svg')
    }

    $overrides_dir = '/opt/bankidp/overrides'
    ensure_resource('sunet::misc::create_dir', $overrides_dir, { owner => 'root', group => 'root', mode => '0750'})
    file { "${overrides_dir}/.messages":
      ensure  => 'file',
      mode    => '0755',
      owner   => 'root',
      content => file('sunet/bankidp/dot-messages')
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
      numnodes => 1,
      hostmode => true,
      tls      => true
    }

    file { "/etc/ssl/certs/${fqdn}_infra.crt":
      mode   => '0644',
    }

    file { "/etc/ssl/private":
      mode   => '711',
    }

    package { ['redis-tools']:
      ensure => installed,
    }
  }
}
