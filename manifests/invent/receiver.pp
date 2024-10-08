# Invent frontend server
class sunet::invent::receiver (
  String $docker_tag = '0.0.1-1',
  String $interface  = 'ens3',
  String $vhost = 'invent.sunet.se'
){
  $admin_password = lookup('invent_admin_password', undef, undef, undef)
  $endpoints = ['hosts', 'images', 'network']
  $nginx_dirs = [ 'acme', 'certs','conf','dhparam','html','vhost' ]
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

  file { '/opt/receiver/nginx':
    ensure => directory,
  }
  $nginx_dirs.each |$dir| {
    file { "/opt/receiver/nginx/${dir}":
      ensure => directory
    }
  }

  if $::facts['sunet_nftables_enabled'] == 'yes' {
    sunet::nftables::docker_expose { 'receiver_80_port' :
      iif           => $interface,
      allow_clients => 'any',
      port          => 80,
    }
    sunet::nftables::docker_expose { 'receiver_443_port' :
      iif           => $interface,
      allow_clients => 'any',
      port          => 443,
    }
    sunet::nftables::rule { 'allow_rsync':
      rule => "add rule inet filter input ip saddr {$ni_host_ip} tcp dport 22 counter accept comment \"allow-rsync-from-ni-host\""
    }
  } else {
    sunet::misc::ufw_allow { 'receiver_ports':
      from => 'any',
      port => [80, 443],
    }
  }

  sunet::rrsync { '/opt/receiver/':
    ssh_key_type       => 'ssh-ed25519',
    ssh_key            => $ni_host_key,
    use_sunet_ssh_keys => true,
  }
}
