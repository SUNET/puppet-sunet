class sunet::pkcs11_ca(
  String $ca_url,
  String $ca_dns_name,
  String $acme_root                      = '/acme',
  String $pkcs11_sign_api_token          = lookup('pkcs11_sign_api_token', String, undef, ''), # Example 'xyz' Taken from eyaml, here for clarity
  String $pkcs11_token                   = 'my_test_token_1',
  String $pkcs11_pin                     = lookup('pkcs11_pin', String, undef, ''), # Example '1234' Taken from eyaml, here for clarity
  String $pkcs11_module                  = '/usr/lib/softhsm/libsofthsm2.so',
  String $postgres_host                  = 'postgres',
  String $postgres_database              = 'pkcs11_testdb1',
  String $postgres_user                  = 'pkcs11_testuser1',
  String $postgres_password              = lookup('postgres_password', String, undef, ''), # Example 'DBUserPassword' Taken from eyaml, here for clarity
  String $postgres_port                  = '5432',
  String $postgres_timeout               = '5',
  String $postgres_image     = 'postgres',
  String $postgres_version     = '15.2-bullseye@sha256:f1f635486b8673d041e2b180a029b712a37ac42ca5479ea13029b53988ed164c',
) {
  include stdlib

  if $pkcs11_sign_api_token == '' or $pkcs11_pin == '' or $postgres_password == '' {
    err('ERROR: missing value in hiera for pkcs11_sign_api_token, pkcs11_pin or postgres_password')
  }

  # clone down the pkcs11 code
  exec { 'pkcs11_ca_clone':
    command => '/usr/bin/git clone https://github.com/SUNET/pkcs11_ca.git',
    cwd     => '/opt',
    unless  => '/usr/bin/ls pkcs11_ca 2> /dev/null',
  }

  # Update the detup variables
  file { '/opt/pkcs11_ca/deploy.sh':
    ensure  => file,
    content => template('sunet/pkcs11_ca/deploy.sh.erb'),
  }

  # Setup the pkcs11_ca system
  exec { 'pkcs11_ca_deploy':
    command => '/usr/bin/bash ./deploy.sh',
    cwd     => '/opt/pkcs11_ca',
    unless  => '/usr/bin/ls data/db_data 2> /dev/null',
  }

  sunet::docker_compose { 'pkcs11_ca_compose':
    content          => template('sunet/pkcs11_ca/docker-compose.yml.erb'),
    service_name     => 'pkcs11_ca',
    compose_dir      => '/opt/',
    compose_filename => 'docker-compose.yml',
    description      => 'PKCS11 CA',
  }

}
