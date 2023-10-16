class sunet::vc::standalone::test(
  String  $vc_version="latest",
  String  $mongodb_version="4.0.10",
  String  $mockca_sleep="20",
  String  $ca_token,
  String  $interface="ens3",
  Boolean $production=false,
  String $ca_url,
  String $ca_pdfsign_url,
  #String $ca_dns_name,
  String $acme_root               = '/acme',
  String $pkcs11_sign_api_token   = lookup('pkcs11_sign_api_token'), 
  String $pkcs11_token            = 'my_test_token_1',
  String $pkcs11_pin              = lookup('pkcs11_pin'), 
  String $pkcs11_module           = '/usr/lib/softhsm/libsofthsm2.so',
  String $postgres_host           = 'ca_postgres',
  String $postgres_database       = 'pkcs11_testdb1',
  String $postgres_user           = 'pkcs11_testuser1',
  String $postgres_password       = lookup('postgres_password'), 
  String $postgres_port           = '5432',
  String $postgres_timeout        = '5',
  String $postgres_image		      = 'postgres',
  String $postgres_version		    = '15.2-bullseye@sha256:f1f635486b8673d041e2b180a029b712a37ac42ca5479ea13029b53988ed164c',
  String $ca_version              = "latest",
  String $ca_reason               = "Ladok",
  String $ca_location             = "Tidan"
  #hash with basic_auth key/value
) {

  sunet::misc::system_user { 'sunet':
    username   => 'sunet',
    group      => 'sunet',
    shell      => '/bin/false',
    managehome => false
  }

  file { '/var/log/sunet':
    ensure => directory,
    mode    => '0770',
    group   => 'sunet',
    require =>  [ Group['sunet'] ],
  }

  file { '/opt/vc/config.yaml':
    ensure => file,
    mode   => '0400',
    owner  => 'root',
    group  => 'root',
    content => template("sunet/vc/standalone/test/config.yaml.erb")
   }

  file { '/opt/vc/haproxy.cfg':
    ensure  => file,
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content =>  template("sunet/vc/standalone/test/haproxy.cfg.erb")
  }

  file { '/opt/pkcs11_ca':
    ensure => directory,
    mode    => '0755',
    owner   => 'root',
    group   => 'root',
  }

  file { '/opt/pkcs11_ca/mk_keys.sh':
    ensure  => file,
    mode    => '0744',
    owner   => 'root',
    group   => 'root',
    content => template('sunet/vc/standalone/mk_keys.sh.erb'),
  }

  file { '/opt/pkcs11_ca/postgres_shell.sh':
    ensure  => file,
    mode    => '0744',
    owner   => 'root',
    group   => 'root',
    content => template('sunet/vc/standalone/postgres_shell.sh.erb'),
  }

  # Setup the pkcs11_ca keys
  exec { 'mk_keys':
    command     => '/usr/bin/bash ./mk_keys.sh',
    cwd         => '/opt/pkcs11_ca',
  }

  file { '/opt/pkcs11_ca/data/hsm_tokens':
    ensure  => directory,
    mode    => '0755',
    owner   => 'root',
    group   => '1500',
  }

  file { '/opt/pkcs11_ca/data/db_data': 
    ensure  => directory,
    mode    => '0755',
    owner   => 'root',
    group   => '999',
  }


  # Compose
  sunet::docker_compose { 'vc_standalone':
    content          => template('sunet/vc/standalone/test/docker-compose.yml.erb'),
    service_name     => 'vc',
    compose_dir      => '/opt',
    compose_filename => 'docker-compose.yml',
    description      => 'VC-standalone service',
  }

  if $::facts['sunet_nftables_enabled'] == 'yes' {
    sunet::nftables::docker_expose { 'web_http_port' :
      iif           => $interface,
      allow_clients => 'any',
      port          => 80,
    }
    sunet::nftables::docker_expose { 'web_https_port' :
      iif           => $interface,
      allow_clients => 'any',
      port          => 443,
    }
  } else {
    sunet::misc::ufw_allow { 'web_ports':
      from => 'any',
      port => ['80', '443']
    }
  }
}
