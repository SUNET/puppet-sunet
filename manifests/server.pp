class sunet::server(
  $fail2ban = true,
  $encrypted_swap = true,
  $ethernet_bonding = true,
  $sshd_config = true,
  $ntpd_config = true,
  $scriptherder = true,
  $unattended_upgrades = false,
  $disable_ipv6_privacy = false,
  $disable_all_local_users = false,
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
    class { 'sunet::security::configure_sshd': }
    include ufw
    ufw::allow { "allow-ssh-from-all":
        port => 22,
    }
  }

  if $ntpd_config {
    include sunet::ntp
  }

  if $scriptherder {
    sunet::snippets::scriptherder { 'sunet_scriptherder': }
  }

  if $unattended_upgrades {
    class { 'sunet::security::unattended_upgrades': }
  }

  if $disable_ipv6_privacy {
    sunet::snippets::disable_ipv6_privacy { 'disable_ipv6_privacy': }
  }

  if $disable_all_local_users {
    class { 'sunet::security::disable_all_local_users': }
  }
}
