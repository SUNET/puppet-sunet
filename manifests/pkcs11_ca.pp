class sunet::pkcs11_ca(
  String $ca_url,
  String $ca_dns_name,
  String $acme_root                      = '/acme',
  String $pkcs11_sign_api_token          = 'xyz',
  String $pkcs11_token                   = 'my_test_token_1',  # remove default arg to require user to set it
  String $pkcs11_pin                     = '1234',  # remove default arg to require user to set it
  String $pkcs11_module                  = '/usr/lib/softhsm/libsofthsm2.so',
  String $postgres_host                  = 'postgres',
  String $postgres_database              = 'pkcs11_testdb1',
  String $postgres_user                  = 'pkcs11_testuser1',
  String $postgres_password              = 'DBUserPassword',  # remove default arg to require user to set it
  String $postgres_port                  = '5432',
  String $postgres_timeout               = '5',
) {
  include stdlib

  # clone down the pkcs11 code
  exec { 'pkcs11_ca_clone':
    command     => '/usr/bin/git clone https://github.com/SUNET/pkcs11_ca.git',
    cwd         => '/opt',
    unless => '/usr/bin/ls pkcs11_ca 2> /dev/null',
  }

  sunet::docker_compose { 'pkcs11_ca_compose':
    content          => template('sunet/pkcs11_ca/docker-compose.yml.erb'),
    service_name     => 'pkcs11_ca',
    compose_dir      => '/opt/',
    compose_filename => 'docker-compose.yml',
    description      => 'PKCS11 CA',
  }


}