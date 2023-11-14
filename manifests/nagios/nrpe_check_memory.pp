# Set up the memory check
define sunet::nagios::nrpe_check_memory (
  Integer $warning = 90,
  Integer $critical = 95,
) {
    sunet::nagios::nrpe_command {'check_memory':
      command_line => "/usr/lib/nagios/plugins/check_memory -w ${warning} -c ${critical}"
    }
}
