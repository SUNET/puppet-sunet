# acmed - automatated
class sunet::certbot::acmed(
  String $server = 'https://acme-d.sunet.se',
){

  include sunet::packages::certbot
  include sunet::packages::python3_requests

  file { '/etc/letsencrypt/acme-dns-auth.py':
    ensure  => file,
    mode    => '0700',
    content => template('sunet/certbot/acme-dns-auth.py.erb'),
  }

  $acmed_clients = lookup('certbot_acmed_clients', undef, undef, {})
  file { '/etc/letsencrypt/acmedns.json':
    content => inline_template("<%= @acmed_clients.to_json %>\n"),
    notify  => Exec['certbot_issuing'],
  }
  $domain_arg = join($acmed_clients.keys, ' -d ')

  exec {'certbot_issuing':
    command     => "certbot certonly --no-eff-email --agree-tos -m noc@sunet.se --manual --manual-auth-hook /etc/letsencrypt/acme-dns-auth.py --preferred-challenges dns -d ${domain_arg}",
    refreshonly => true,
  }

  $agent_ips = lookup('acmed_agent_ips', undef, undef, [])
  $agent_ips.each |$ip| {
    sunet::nftables::allow { "allow_agent_${ip}":
      from => $ip,
      port => 22,
    }
  }
  sunet::ssh_keys { 'agent-keys':
    config            => safe_hiera('acmed_agent_ssh_keys_mapping', {}),
    key_database_name => 'acmed_agent_ssh_keys_db'
  }
}
