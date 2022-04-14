class sunet::server(
  Boolean $fail2ban = true,
  Boolean $encrypted_swap = true,
  Boolean $ethernet_bonding = true,
  Boolean $sshd_config = true,
  Boolean $ntpd_config = true,
  Boolean $scriptherder = true,
  Boolean $unattended_upgrades = false,
  Boolean $unattended_upgrades_use_template = false,
  Boolean $apparmor = false,
  Boolean $disable_ipv6_privacy = false,
  Boolean $disable_all_local_users = false,
  Array $mgmt_addresses = [safe_hiera('mgmt_addresses', [])],
  Optional[Boolean] $ssh_allow_from_anywhere = false,
) {

  if $fail2ban {
    # Configure fail2ban to lock out SSH scanners
    class { 'sunet::fail2ban': }
  }

  if $encrypted_swap {
    # Set up encrypted swap
    sunet::snippets::encrypted_swap { 'sunet_encrypted_swap': }
  }

  if $ethernet_bonding {
    # Add prerequisites for ethernet bonding, if physical server
    sunet::snippets::ethernet_bonding { 'sunet_ethernet_bonding': }
  }

  if $sshd_config {
    $ssh_port = hiera('sunet_ssh_daemon_port', undef)
    class { 'sunet::security::configure_sshd':
      port => $ssh_port,
    }
    if $::sunet_nftables_opt_in != 'yes' and ! ( $::operatingsystem == 'Ubuntu' and versioncmp($::operatingsystemrelease, '22.04') >= 0 ) {
      notice('Enabling UFW')
      include ufw
    } else {
      notice('Enabling nftables (opt-in, or Ubuntu >= 22.04)')
      ensure_resource ('class','sunet::nftables::init', { })
    }
    if $ssh_allow_from_anywhere {
      sunet::misc::ufw_allow { 'allow-ssh-from-all':
        from => 'any',
        port => pick($ssh_port, 22),
      }
    } else {
      # Remove any existing rule from when ssh_allow_from_anywhere was true as default
      ensure_resource('sunet::misc::ufw_allow', 'remove_ufw_allow_all_ssh', {
        ensure => 'absent',
        from   => 'any',
        to     => 'any',
        proto  => 'tcp',
        port   => sprintf('%s', pick($ssh_port, 22)),
      })

      if $::ipaddress_default {
        # Also remove historical allow-any-to-my-IP rules
        ensure_resource('sunet::misc::ufw_allow', 'remove_ufw_allow_all_ssh_to_my_ip', {
          ensure => 'absent',
          from   => 'any',
          to     => $::ipaddress_default,
          proto  => 'tcp',
          port   => sprintf('%s', pick($ssh_port, 22)),
        })
      }
    }
    if $mgmt_addresses != [] {
      sunet::misc::ufw_allow { 'allow-ssh-from-mgmt':
        from => $mgmt_addresses,
        port => pick($ssh_port, 22),
      }
    }
  }

  if $ntpd_config {
    include sunet::ntp
  }

  if $scriptherder {
    sunet::snippets::scriptherder { 'sunet_scriptherder': }
  }

  if $unattended_upgrades {
    class { 'sunet::security::unattended_upgrades':
      use_template => $unattended_upgrades_use_template,
    }
  }

  if $apparmor {
    class { 'sunet::security::apparmor': }
  }

  if $disable_ipv6_privacy {
    sunet::snippets::disable_ipv6_privacy { 'disable_ipv6_privacy': }
  }

  if $disable_all_local_users {
    class { 'sunet::security::disable_all_local_users': }
  }

  if $::is_virtual == true {
    file { '/usr/local/bin/sunet-reinstall':
      ensure  => file,
      mode    => '0755',
      content => template('sunet/cloudimage/sunet-reinstall.erb'),
    }
    sunet::scriptherder::cronjob { 'sunet_reinstall':
      # sleep 150 to avoid running at the same time as the cronjob fetching new certificates
      cmd           => "sh -c 'sleep 150; /usr/local/bin/sunet-reinstall -f'",
      ok_criteria   => ['exit_status=0', 'max_age=25h'],
      warn_criteria => ['exit_status=0', 'max_age=49h'],
      special       => 'daily',
    }
  }

  if $facts['dmi']['product']['name'] == 'OpenStack Compute' {
    class { 'sunet::iaas::server': }
  }
}
