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

  # Group domains into certs by (effective CA URL, cert_name).
  # cert_name is optional — domains without it are all merged into one cert per
  # CA URL (backwards compatible). Domains sharing a cert_name are issued as a
  # single SAN cert with --cert-name <cert_name>.
  $certs = $acmed_clients.reduce({}) |Hash $acc, Array $entry| {
    $domain        = $entry[0]
    $config        = $entry[1]
    $effective_url = pick($config['directory_url'], $effective_directory_url)
    $cert_name     = $config['cert_name']
    $group_key     = $cert_name ? { undef => $effective_url, default => "${effective_url}::${cert_name}" }
    $existing      = $group_key in $acc ? {
      true    => $acc[$group_key],
      default => { 'url' => $effective_url, 'cert_name' => $cert_name, 'deploy_hook' => undef, 'domains' => [] }
    }
    $deploy_hook   = $existing['deploy_hook'] ? {
      undef   => $config['deploy_hook'],
      default => $existing['deploy_hook'],
    }
    $acc + { $group_key => $existing + { 'deploy_hook' => $deploy_hook, 'domains' => $existing['domains'] + [$domain] } }
  }

  file { '/etc/letsencrypt/acmedns.json':
    content => inline_template("<%= @acmed_clients.to_json %>\n"),
    notify  => Exec[$certs.keys.map |$k| { "certbot_issuing_${k}" }],
  }

  $certs.each |String $group_key, Hash $cert| {
    $url           = $cert['url']
    $domains       = $cert['domains']
    $domain_arg    = join($domains, ' -d ')
    $cert_name_flag  = $cert['cert_name'] ? { undef => '', default => "--cert-name ${cert['cert_name']} " }
    $deploy_hook_flag = $cert['deploy_hook'] ? { undef => '', default => "--deploy-hook ${cert['deploy_hook']} " }
    $deploy_name     = $cert['cert_name'] ? { undef => $domains[0], default => $cert['cert_name'] }
    exec { "certbot_issuing_${group_key}":
      command     => @("CMD"),
        certbot certonly --server ${url} \
          ${cert_name_flag}${deploy_hook_flag}--expand \
          --force-renewal \
          --no-eff-email \
          --agree-tos \
          -m noc@sunet.se \
          --manual \
          --manual-auth-hook /etc/letsencrypt/acme-dns-auth.py \
          --preferred-challenges dns \
          -d ${domain_arg} \
        && /etc/letsencrypt/issue-and-deploy.sh ${deploy_name}
        | CMD
      refreshonly => true,
    }
  }
}
