# Base class for all Sunet hosts
class sunet::server (
  Boolean $fail2ban = true,
  Boolean $encrypted_swap = true,
  Boolean $ethernet_bonding = true,
  Boolean $sshd_config = true,
  Boolean $ntpd_config = true,
  Boolean $scriptherder = true,
  Boolean $install_scriptherder = false,  # Change to true when all repos have removed their copy of scriptherder
  Boolean $unattended_upgrades = false,
  Boolean $unattended_upgrades_use_template = false,
  Boolean $apparmor = false,
  Boolean $disable_ipv6_privacy = false,
  Boolean $disable_all_local_users = false,
  Array $mgmt_addresses = [safe_hiera('mgmt_addresses', [])],
  Boolean $ssh_allow_from_anywhere = false,
) {
  if $::operatingsystem == 'Debian' and versioncmp($::operatingsystemrelease, '12') >= 0 {
    # These packages are needed to run the other things in this manifest on modern Debian
    include sunet::packages::cron
    include sunet::packages::puppet_module_puppetlabs_cron_core
  }
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
    class { 'sunet::security::allow_ssh':
      allow_from_anywhere => $ssh_allow_from_anywhere,
      mgmt_addresses      => flatten($mgmt_addresses),
      port                => pick($ssh_port, 22),
    }
  }

  if $ntpd_config {
    include sunet::ntp
  }

  if $scriptherder {
    ensure_resource('class', 'sunet::scriptherder::init', { install => $install_scriptherder })
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

  if $::facts['is_virtual'] == true {
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
