# Base class for all Sunet hosts
# @param fail2ban                          Enable fail2ban
# @param encrypted_swap                    Enable encrypted swap
# @param ethernet_bonding                  Enable ethernet bonding
# @param sshd_config                       Configure SSH daemon
# @param ntpd_config                       Configure NTP daemon
# @param scriptherder                      Enable scriptherder
# @param install_scriptherder              Install bundled version of scriptherder
# @param unattended_upgrades               Enable unattended upgrades
# @param unattended_upgrades_use_template  Use template for unattended upgrades config
# @param apparmor                          Enable AppArmor
# @param disable_ipv6_privacy              Disable IPv6 privacy extensions
# @param disable_all_local_users           Disable all local users
# @param mgmt_addresses                    List of management addresses (for SSH access)
# @param ssh_allow_from_anywhere           Allow SSH from anywhere
class sunet::server (
  Boolean $fail2ban = true,
  Boolean $encrypted_swap = true,
  Boolean $ethernet_bonding = true,
  Boolean $nftables_init = true,
  Boolean $sshd_config = true,
  Boolean $ntpd_config = true,
  Boolean $scriptherder = true,
  Boolean $install_scriptherder = false,  # Change to true when all repos have removed their copy of scriptherder
  Boolean $unattended_upgrades = false,
  Boolean $unattended_upgrades_use_template = false,
  Boolean $apparmor = false,
  Boolean $disable_ipv6_privacy = false,
  Boolean $disable_all_local_users = false,
  Array $mgmt_addresses = [lookup('mgmt_addresses', undef, undef, [])],
  Boolean $ssh_allow_from_anywhere = false,
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
    $ssh_port = lookup(sunet_ssh_daemon_port, undef, undef, undef)
    class { 'sunet::security::configure_sshd':
      port => $ssh_port,
    }
    class { 'sunet::security::allow_ssh':
      allow_from_anywhere => $ssh_allow_from_anywhere,
      mgmt_addresses      => flatten($mgmt_addresses),
      nftables_init       => $nftables_init,
      port                => pick($ssh_port, 22),
    }
  }

  if $ntpd_config {
    if $::facts['sunet_chrony_enabled'] == 'yes' {
      include sunet::chrony
    } else {
      include sunet::ntp
    }
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

  # Avoid bright red error message on Ubuntu 18.04 with Puppet 5.4
  if $::facts['operatingsystem'] == 'Ubuntu' and
  versioncmp($::facts['operatingsystemrelease'], '18.04') >= 0 and
  versioncmp($::facts['operatingsystemrelease'], '22.04') < 0 {
    sunet::misc::create_dir { '/opt/puppetlabs/puppet/share/augeas':
      owner => 'root',
      group => 'root',
      mode  => '0755',
    }
  }

  if $::facts['is_virtual'] == true {
    file { '/usr/local/bin/sunet-reinstall':
      ensure  => file,
      mode    => '0755',
      content => template('sunet/kvm/sunet-reinstall.erb'),
    }
    sunet::scriptherder::cronjob { 'sunet_reinstall':
      # sleep 150 to avoid running at the same time as the cronjob fetching new certificates
      cmd           => "sh -c 'sleep 150; /usr/local/bin/sunet-reinstall -f'",
      ok_criteria   => ['exit_status=0', 'max_age=25h'],
      warn_criteria => ['exit_status=0', 'max_age=49h'],
      special       => 'daily',
    }
  }

  if $facts['dmi']['product']['name'] =~ /OpenStack\s(Compute|Nova)/ {
    class { 'sunet::iaas::server': }
  }
}
