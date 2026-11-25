# Set up the memory check
define sunet::nagios::nrpe_check_memory (
  String $warning_arg = '',
  String $critical_arg = '',
) {
  include sunet::nagios::nrpe_paths
  if $facts['os']['name'] == 'AlmaLinux' {
    file { "${sunet::nagios::nrpe_paths::plugins}/check_memory":
      source  => 'puppet:///modules/sunet/nagios/check_memory_el',
      mode    => '0755',
      require => Package['nagios-plugins'],
    }
  }

    $default_warning = $facts['os']['distro']['codename'] ? {
      'bullseye' => '10%',
      'focal'    => '10%',
      default    => '90%',

    }

    $default_critical = $facts['os']['distro']['codename'] ? {
      'bullseye' => '5%',
      'focal'    => '5%',
      default    => '95%',
    }

    $_critical = $critical_arg ? {
      '' => $default_critical,
      default => $critical_arg,
    }

    $_warning = $warning_arg ? {
      '' => $default_warning,
      default => $warning_arg,
    }

    sunet::nagios::nrpe_command {'check_memory':
      command_line => "${sunet::nagios::nrpe_paths::plugins}/check_memory -w ${_warning} -c ${_critical}"
    }
}
