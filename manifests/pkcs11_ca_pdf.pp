class sunet::pkcs11_ca_pdf(
  #String $ca_url,
  #String $ca_dns_name,
  String $acme_root               = '/acme',
  String $pkcs11_sign_api_token   = lookup('pkcs11_sign_api_token'), 
  String $pkcs11_token            = 'my_test_token_1',
  String $pkcs11_pin              = lookup('pkcs11_pin'), 
  String $pkcs11_module           = '/usr/lib/softhsm/libsofthsm2.so',
  String $postgres_host           = 'postgres',
  String $postgres_database       = 'pkcs11_testdb1',
  String $postgres_user           = 'pkcs11_testuser1',
  String $postgres_password       = lookup('postgres_password'), 
  String $postgres_port           = '5432',
  String $postgres_timeout        = '5',
  String $postgres_image		      = 'postgres',
  String $postgres_version		    = '15.2-bullseye@sha256:f1f635486b8673d041e2b180a029b712a37ac42ca5479ea13029b53988ed164c',
  String $ca_version              = "latest"
) {
  include stdlib


  ## clone down the pkcs11 code
  #exec { 'pkcs11_ca_clone':
  #  command     => '/usr/bin/git clone https://github.com/SUNET/pkcs11_ca.git',
  #  cwd         => '/opt',
  #  unless => '/usr/bin/ls pkcs11_ca 2> /dev/null',
  #}

  # Update the detup variables
  file { '/opt/pkcs11_ca/mk_keys.sh':
    ensure  => file,
    content => template('sunet/pkcs11_ca/pdf/mk_keys.sh.erb'),
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
    group   => '1500'
  }

  file { '/opt/pkcs11_ca/data/db_data': 
    ensure  => directory,
    mode    => '0755',
    owner   => 'root',
    group   => '999'
  }

  #chmod 644 data/tls_key*.key


  sunet::docker_compose { 'pkcs11_ca':
    content          => template('sunet/pkcs11_ca/pdf/docker-compose.yml.erb'),
    service_name     => 'pkcs11_ca',
    compose_dir      => '/opt/',
    compose_filename => 'docker-compose.yml',
    description      => 'PKCS11 CA',
  }

}
