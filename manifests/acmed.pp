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
  file { '/etc/letsencrypt/certbot-renew-post-hook-wrapper':
    ensure  => file,
    mode    => '0700',
    content => file('sunet/acmed/certbot-renew-post-hook-wrapper'),
  }

  $acmed_accounts = lookup('acmed_accounts', undef, undef, {})
  file { '/etc/letsencrypt/acmedns.json':
    content => inline_template("<%= @acmed_accounts.to_json %>\n"),
    notify  => Exec['certbot'],
  }
  $domain_arg = join($acmed_accounts.keys, ' -d ')

  exec {'certbot':
    command     => "certbot certonly --no-eff-email --agree-tos -m noc@sunet.se --manual --manual-auth-hook /etc/letsencrypt/acme-dns-auth.py --preferred-challenges dns -d ${domain_arg}",
    refreshonly => true,
  }
}
