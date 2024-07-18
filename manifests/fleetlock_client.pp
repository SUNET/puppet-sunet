# Setup and configure the Sunet fleetlock client
class sunet::fleetlock_client (
  Boolean $cosmos_with_fleetlock = true,
){
  $fleetlock_config =  lookup('fleetlock_config', undef, undef, undef)

  if $fleetlock_config =~ Hash {
    $config_dir = '/etc/sunet-fleetlock'
    exec { "sudo-make-me-a-sandwich_${config_dir}":
      command => "/bin/mkdir -p ${config_dir}",
      unless  => "/usr/bin/test -d ${config_dir}",
    }
    file { "${config_dir}/sunet-fleetlock.conf":
    ensure  => file,
    mode    => '0700',
    content => template('sunet/fleetlock_client/sunet-fleetlock.conf.erb'),
    }
  } else {
    warning('No fleetlock configuration available')
  }

  if $cosmos_with_fleetlock {
    $cosmos_fleetlock_config = lookup('cosmos_fleetlock_config', undef, undef, undef)
    if $cosmos_fleetlock_config =~ Hash {
      file { '/etc/run-cosmos-fleetlock-conf':
      ensure  => file,
      mode    => '0700',
      content => template('sunet/fleetlock_client/run-cosmos-fleetlock-conf.erb'),
      }
    } else {
      warning('Cosmos instructed to use fleetlock but no configuration available')
    }
  }
}
