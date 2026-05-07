# El manual clients for djangoca with acme
class sunet::certbot::djangoca::manual_client (
  String  $directory_url
) {

  include sunet::packages::python3_cryptography
  include sunet::packages::python3_josepy

  file { '/usr/local/bin/generate_acme_key':
    ensure  => present,
    content => file('sunet/certbot/djangoca/generate_acme_key.py'),
    mode    => '0755',
  }

  exec { 'generate_acme_key':
    command => "/usr/local/bin/generate_acme_key --server \"${directory_url}\"",
    creates => '/etc/letsencrypt/accounts/public_key.pem'
  }
}
