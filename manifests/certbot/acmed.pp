# acmed - automatated
class sunet::certbot::acmed(
  String $server           = 'https://acme-d.sunet.se',
  String $directory_url    = 'https://acme-v02.api.letsencrypt.org/directory',
  Optional[String] $ca_url = undef,  # deprecated alias for $directory_url
){
  $effective_directory_url = pick($ca_url, $directory_url)

  include sunet::packages::certbot
  include sunet::packages::python3_requests

  file { '/etc/letsencrypt/acme-dns-auth.py':
    ensure  => file,
    mode    => '0700',
    content => template('sunet/certbot/acme-dns-auth.py.erb'),
  }

  file { '/etc/letsencrypt/issue-and-deploy.sh':
    ensure  => file,
    mode    => '0700',
    content => file('sunet/certbot/issue-and-deploy.sh'),
  }

  $acmed_clients = lookup('certbot_acmed_clients', undef, undef, {})
  file { '/etc/letsencrypt/acmedns.json':
    content => inline_template("<%= @acmed_clients.to_json %>\n"),
    notify  => Exec[$domains_by_ca.keys.map |$url| { "certbot_issuing_${url}" }],
  }

  # Group domains by their effective CA URL (directory).
  # A per-domain directory_url inside certbot_acmed_clients
  # takes precedence over the class-level $directory_url.
  $domains_by_ca = $acmed_clients.reduce({}) |Hash $acc, Array $entry| {
    $domain        = $entry[0]
    $config        = $entry[1]
    $effective_url = pick($config['directory_url'], $effective_directory_url)
    $existing      = $effective_url in $acc ? { true => $acc[$effective_url], default => [] }
    $acc + { $effective_url => $existing + [$domain] }
  }

  $domains_by_ca.each |String $url, Array $domains| {
    $domain_arg = join($domains, ' -d ')
    exec { "certbot_issuing_${url}":
      command     => @("CMD"),
        certbot certonly --server ${url} \
                                       --no-eff-email \
                                       --agree-tos \
                                       -m noc@sunet.se \
                                       --manual \
                                       --manual-auth-hook /etc/letsencrypt/acme-dns-auth.py \
                                       --preferred-challenges dns \
                                       -d ${domain_arg} \
        && /etc/letsencrypt/issue-and-deploy.sh ${domains[0]}
        | CMD
      refreshonly => true,
    }
  }
}
