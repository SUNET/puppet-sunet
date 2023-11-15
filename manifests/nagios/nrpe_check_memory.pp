# Set up the memory check
define sunet::nagios::nrpe_check_memory (
  String $warning_arg = '',
  String $critical_arg = '',
) {

    $default_warning = $facts['os']['codename'] ? {
      'bullseye' => '10%',
      'focal'    => '10%',
      default    => '90%',

    }

    $default_critical = $facts['os']['codename'] ? {
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
      command_line => "/usr/lib/nagios/plugins/check_memory -w ${_warning} -c ${_critical}"
    }
}
