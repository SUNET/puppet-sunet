# acmed - automatated
class sunet::acmed(
  String $server = 'https://acme-d.sunet.se',
){

  include sunet::packages::certbot
  include sunet::packages::python3_requests

  file { '/etc/letsencrypt/acme-dns-auth.py':
    ensure  => file,
    mode    => '0700',
    content => template('sunet/acmed/acme-dns-auth.py.erb'),
  }

  $acmed_accounts = lookup('acmed_accounts', undef, undef, {})
  file { '/etc/letsencrypt/acmedns.json':
    content => inline_template("<%= @acmed_accounts.to_json %>\n"),
  }
}
