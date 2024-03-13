# acmed - automatated
class sunet::acmed(
  String $server = 'https://acme-d.sunet.se',
){

  include sunet::packages::certbot
  include sunet::packages::python3_requests

  file { '/etc/letsencrypt/acme-dns-auth.py':
    ensure  => file,
    content => template('sunet/acmed/acme-dns-auth.py.erb'),
  }
}
