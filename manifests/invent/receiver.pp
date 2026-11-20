# Invent frontend server
#
# @param additional_vhosts Extra vhosts to proxy, keyed by hostname. Each entry
#   names the backend container (its Docker DNS name) and the port it listens
#   on. The backends run in other compose projects and must join this stack's
#   default network (receiver_default) as an external network.
#   Example:
#     hittade.sunet.se:
#       backend: hittade-web
#       port: 8080
class sunet::invent::receiver (
  String $docker_tag = '0.0.1-1',
  String $interface  = 'ens3',
  String $vhost = 'invent.sunet.se',
  Hash[String, Struct[{ backend => String[1], port => Integer[1, 65535] }]] $additional_vhosts = {},
){
  if $vhost in $additional_vhosts {
    fail("sunet::invent::receiver: ${vhost} is the main vhost and can't be in additional_vhosts")
  }
  $admin_password = lookup('invent_admin_password', undef, undef, undef)
  $endpoints = ['hosts', 'images', 'network']
  $ni_host_key = lookup ('ni_host_key')
  $ni_host_ip = lookup ('ni_host_ip')

  sunet::docker_compose { 'invent_reciver':
    content          => template('sunet/invent/receiver/docker-compose.yml.erb'),
    service_name     => 'receiver',
    compose_dir      => '/opt/',
    compose_filename => 'docker-compose.yml',
    description      => 'Invent receiver Server',
  }

  file { '/opt/receiver/db':
    ensure => directory,
    owner  => '999',
  }
  $endpoints.each |$endpoint| {
    file { "/opt/receiver/${endpoint}":
      ensure => directory,
      owner  => '999',
    }
  }

  # Kept outside /opt/receiver, which is writable through the rrsync key below,
  # so the ACME account key and certificates are not reachable that way.
  file { ['/opt/caddy', '/opt/caddy/data', '/opt/caddy/config']:
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0751',
  }
  file { '/opt/caddy/Caddyfile':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => template('sunet/invent/receiver/Caddyfile.erb'),
  }

  if $::facts['sunet_nftables_enabled'] == 'yes' {
    sunet::nftables::docker_expose { 'receiver_443_port' :
      iif           => $interface,
      allow_clients => 'any',
      port          => 443,
    }
    sunet::nftables::rule { 'allow_rsync':
      rule => "add rule inet filter input ip saddr {${ni_host_ip}} tcp dport 22 counter accept comment \"allow-rsync-from-ni-host\""
    }
  } else {
    sunet::misc::ufw_allow { 'receiver_ports':
      from => 'any',
      port => [443],
    }
  }

  sunet::rrsync { '/opt/receiver/':
    ssh_key_type       => 'ssh-ed25519',
    ssh_key            => $ni_host_key,
    use_sunet_ssh_keys => true,
  }
}
