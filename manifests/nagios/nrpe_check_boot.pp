# Check boot
define sunet::nagios::nrpe_check_boot (
  String $critical = '10%',
  String $warning = '20%',
) {
    sunet::nagios::nrpe_command {'check_boot':
      command_line => "/usr/lib/nagios/plugins/check_disk -w ${warning} -c ${critical} -p /boot"
    }
}
