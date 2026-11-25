# Keep the existing check_apt command available to older monitoring configs.
define sunet::nagios::nrpe_check_apt () {
  include sunet::nagios::package_updates
  if $facts['os']['name'] == 'AlmaLinux' {
    sunet::nagios::nrpe_command { 'check_apt':
      command_line => $sunet::nagios::package_updates::plugin,
    }
  }
}
