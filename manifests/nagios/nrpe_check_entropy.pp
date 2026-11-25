# Check entropy
define sunet::nagios::nrpe_check_entropy (
  Integer $warning = 256,
) {
  include sunet::nagios::nrpe_paths
  if $facts['os']['name'] == 'AlmaLinux' {
    file { "${sunet::nagios::nrpe_paths::plugins}/check_entropy":
      source  => 'puppet:///modules/sunet/nagios/check_entropy_el',
      mode    => '0755',
      require => Package['nagios-plugins'],
    }
  }

    sunet::nagios::nrpe_command { 'check_entropy':
      command_line => "${sunet::nagios::nrpe_paths::plugins}/check_entropy -w ${warning}",
    }
}
