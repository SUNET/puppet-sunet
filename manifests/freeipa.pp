# 389 ds class for SUNET
class sunet::freeipa(
  Array[String] $client_ips,
  String $dir_suffix,
  String $interface = 'ens3',
  String $freeipa_image  = 'quay.io/freeipa/freeipa-server',
  String $freeipa_tag    = 'fedora-38',
)
{
  $hostname = $facts['networking']['fqdn']
  $dir_manager_password = lookup('dir_manager_password')
  # Composefile
  sunet::docker_compose { 'freeipa':
    content          => template('sunet/freeipa/docker-compose.erb.yml'),
    service_name     => 'freeipa',
    compose_dir      => '/opt',
    compose_filename => 'docker-compose.yml',
    description      => '389 DS',
  }
  $ports = [3389, 3636]
  $ports.each|$port| {
    sunet::nftables::docker_expose { "ldap_port_${port}":
      allow_clients => $client_ips,
      port          => $port,
      iif           => $interface,
    }
  }
  file { '/opt/freeipa/data':
    ensure => directory,
    owner  => 389,
    group  => 389,
  }
  file { '/usr/local/bin/bootstrap_replication':
    ensure  => file,
    content => template('sunet/freeipa/bootstrap_replication.erb.sh'),
    mode    => '0740',
    owner   => 'root',
    group   => 'root',

  }

  $ds_commands = ['ds-logpipe.py', 'dsconf', 'dsctl', 'ds-replcheck', 'dscreate', 'dsidm', 'ipa']
  $ds_commands.each|$command|{
    file {"/usr/local/bin/${command}":
      ensure  => file,
      content => inline_template("#!/bin/bash\ndocker exec -ti freeipa_ldap_1 ${command} \"\${@}\""),
      owner   => 'root',
      group   => 'root',
      mode    => '0744',
    }
  }
}
