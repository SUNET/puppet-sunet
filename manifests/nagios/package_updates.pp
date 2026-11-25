# Install the native monitor used by both the portable and legacy checks.
class sunet::nagios::package_updates {
  include sunet::nagios::nrpe_paths
  if $facts['os']['name'] == 'AlmaLinux' {
    $command = 'check_updates'
    $plugin = "${sunet::nagios::nrpe_paths::plugins}/check_dnf_updates"
    file { $plugin:
      mode    => '0755',
      source  => 'puppet:///modules/sunet/nagios/check_dnf_updates',
      require => Package['nagios-plugins'],
    }
  } else {
    $command = 'check_apt'
    $plugin = '/usr/lib/nagios/plugins/check_apt-wrapper'
    file { $plugin:
      ensure  => file,
      mode    => '0755',
      owner   => 'root',
      content => file('sunet/nagios/check_apt-wrapper'),
    }
  }
  sunet::nagios::nrpe_command { $command:
    command_line => $plugin,
  }
}
