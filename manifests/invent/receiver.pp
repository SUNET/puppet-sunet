# Invent frontend server
#
# @param additional_vhosts Extra vhosts to proxy, keyed by hostname. Each entry
#   names the backend container (its Docker DNS name) and the port it listens
#   on. The backends run in other compose projects and must join this stack's
#   default network (receiver_default) as an external network.
#   sunet::hittade registers its own hostname when declared on this node.
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

  $compose = $facts['dockerhost2'] ? {
    'yes'   => '/usr/bin/docker compose',
    default => '/usr/local/bin/docker-compose',
  }
  $receiver_compose = "${compose} -p receiver -f /opt/receiver/docker-compose.yml"
  sunet::docker_compose { 'invent_reciver':
    content          => template('sunet/invent/receiver/docker-compose.yml.erb'),
    service_name     => 'receiver',
    compose_dir      => '/opt/',
    compose_filename => 'docker-compose.yml',
    description      => 'Invent receiver Server',
    start_command    => "${receiver_compose} up --remove-orphans --force-recreate --no-deps",
  }

  # Restart the running nginx-era unit with its new ExecStart on upgrade.
  # The wrapper omits the unit on hosts where Docker networking is not ready.
  File <| title == '/etc/systemd/system/sunet-receiver.service' |> ~> Service <| title == 'sunet-receiver' |>

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

  # Keep Caddy's keys outside the tree exported by rrsync.
  $caddy_dirs = ['/opt/caddy', '/opt/caddy/conf', '/opt/caddy/data', '/opt/caddy/config']
  file { $caddy_dirs:
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0751',
    before => Sunet::Docker_compose['invent_reciver'],
  }
  $caddyfile = '/opt/caddy/conf/Caddyfile'
  concat { $caddyfile:
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    require => File['/opt/caddy/conf'],
    before  => Sunet::Docker_compose['invent_reciver'],
  }
  concat::fragment { 'invent-caddy-global-options':
    target  => $caddyfile,
    order   => '00',
    content => file('sunet/invent/receiver/caddy-global-options'),
  }
  sunet::invent::receiver::vhost { $vhost:
    backend => 'invent-receiver',
    port    => 8000,
  }
  $additional_vhosts.each |$host, $target| {
    ensure_resource('sunet::invent::receiver::vhost', $host, $target)
  }

  # Record only successful reloads so a transient failure is retried next run.
  $applied = '/opt/caddy/Caddyfile.applied'
  $reload = "${receiver_compose} exec -T caddy caddy reload --config /etc/caddy/Caddyfile"
  exec { 'reload-invent-caddy':
    command   => "${reload} && /usr/bin/install -m 0600 ${caddyfile} ${applied}",
    unless    => "/usr/bin/cmp -s ${caddyfile} ${applied}",
    onlyif    => '/bin/systemctl is-active --quiet sunet-receiver.service',
    require   => Sunet::Docker_compose['invent_reciver'],
    tries     => 5,
    try_sleep => 2,
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
