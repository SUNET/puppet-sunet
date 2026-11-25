# Check reboot
define sunet::nagios::nrpe_check_reboot (
) {
  include sunet::nagios::nrpe_paths
  if $facts['os']['name'] == 'AlmaLinux' {
    ensure_packages(['dnf-plugins-core'])
    Package['nagios-plugins'] -> File["${sunet::nagios::nrpe_paths::plugins}/check_reboot"]
  }

  file { "${sunet::nagios::nrpe_paths::plugins}/check_reboot" :
      ensure  => 'file',
      mode    => '0751',
      group   => $sunet::nagios::nrpe_paths::user,
      require => Package[$sunet::nagios::nrpe_paths::service],
      content => template('sunet/nagioshost/check_reboot.erb'),
  }

  sunet::nagios::nrpe_command {'check_reboot':
    command_line => "${sunet::nagios::nrpe_paths::plugins}/check_reboot"
  }
}
