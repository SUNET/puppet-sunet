# Check /
define sunet::nagios::nrpe_check_root (
  String $critical = '5%',
  String $warning = '15%',
) {
    sunet::nagios::nrpe_command {'check_root':
      command_line => "/usr/lib/nagios/plugins/check_disk -w ${warning} -c ${critical} -p /"
    }
}
