# Set up SSH access to the host
# @param port                 The port sshd listens on
# @param mgmt_addresses       An array of IP addresses or subnets to allow SSH access from
# @param allow_from_anywhere  Allow SSH access from anywhere (default: false)
class sunet::security::allow_ssh (
  Integer       $port,
  Array[String] $mgmt_addresses = [],
  Boolean       $allow_from_anywhere = false,
  Boolean       $nftables_init = true,
) {
  if $::facts['sunet_nftables_enabled'] != 'yes' {
    notice('Enabling UFW')
    include ufw
  } elsif $nftables_init {
    notice('Enabling nftables (opt-in, or Ubuntu >= 22.04)')
    ensure_resource ('class','sunet::nftables::init', {})
  }

  if $allow_from_anywhere {
    notice('Allowing SSH access from ANYWHERE to this host')
    sunet::misc::ufw_allow { 'allow-ssh-from-all':
      from => 'any',
      port => $port,
    }
  } else {
    # Remove any existing rule from when ssh_allow_from_anywhere was true as default
    ensure_resource('sunet::misc::ufw_allow', 'remove_ufw_allow_all_ssh', {
        ensure => 'absent',
        from   => 'any',
        to     => 'any',
        proto  => 'tcp',
        port   => $port,
    })

    if $facts['networking']['ip'] {
      # Also remove historical allow-any-to-my-IP rules
      ensure_resource('sunet::misc::ufw_allow', 'remove_ufw_allow_all_ssh_to_my_ip', {
          ensure => 'absent',
          from   => 'any',
          to     => $facts['networking']['ip'],
          proto  => 'tcp',
          port   => $port,
      })
    }
  }
  if $mgmt_addresses != [] {
    sunet::misc::ufw_allow { 'allow-ssh-from-mgmt':
      from => $mgmt_addresses,
      port => $port,
    }
  } else {
    notice('SSH from anywhere is disabled, and no mgmt_addresses provided. Not allowing SSH access from anywhere.')
  }
}
