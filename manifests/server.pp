class sunet::server(
  Boolean $fail2ban = true,
  Boolean $encrypted_swap = true,
  Boolean $ethernet_bonding = true,
  Boolean $sshd_config = true,
  Boolean $ntpd_config = true,
  Boolean $scriptherder = true,
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
    sunet::security::configure_sshd { 'basic_sshd_config' }
  }

  if $ntpd_config {
    include sunet::ntp
  }

  if $scriptherder {
    file { '/var/cache/scriptherder':
      ensure  => 'directory',
      path    => '/var/cache/scriptherder',
      mode    => '1777',    # like /tmp, so user-cronjobs can also use scriptherder
    }
  }

}

