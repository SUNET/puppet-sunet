# Setup and configure the Sunet fleetlock client
class sunet::fleetlock_client (
  Boolean $cosmos_with_fleetlock = True,
){
  $fleetlock_config =  lookup('fleetlook_config', undef, undef, undef)

  if $fleetlock_config =~ Hash {
    file { '/etc/sunet-fleetlock/sunet-fleetlock.conf':
    ensure  => file,
    mode    => '0700',
    content => template('sunet/fleetlock_client/sunet-fleetlock.conf.erb'),
    }
  } else {
    warning('No fleetlock configuration available')
  }

  if $cosmos_with_fleetlock {
    $cosmos_fleetlock_config = lookup('cosmos_fleetlook_config', undef, undef, undef)
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
