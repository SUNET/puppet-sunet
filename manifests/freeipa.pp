# freeIPIA class for SUNET
class sunet::freeipa(
  String $interface = 'ens3',
  String $freeipa_image  = 'quay.io/freeipa/freeipa-server',
  String $freeipa_tag    = 'fedora-38',
  String $hostname   = 'dc.sunet.dev',
  String $domain   = 'sunet.dev',
  String $realm   = 'SUNET.DEV',
)
{
  $ip_address = $facts['networking']['ip']
  $password = lookup('dir_manager_password')
  # Composefile
  sunet::docker_compose { 'freeipa':
    content          => template('sunet/freeipa/docker-compose.erb.yml'),
    service_name     => 'freeipa',
    compose_dir      => '/opt',
    compose_filename => 'docker-compose.yml',
    description      => 'FreeIPA',
  }
  $ports = [53,80,88,123,389,443,464,636]
  $ports.each|$port| {
    sunet::nftables::docker_expose { "ldap_port_${port}":
      allow_clients => 'any',
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
      content => inline_template("#!/bin/bash\ndocker exec -ti freeipa-ldap-1 ${command} \"\${@}\""),
      owner   => 'root',
      group   => 'root',
      mode    => '0744',
    }
  }
}
