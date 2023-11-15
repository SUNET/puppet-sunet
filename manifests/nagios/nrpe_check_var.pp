# Check /var
define sunet::nagios::nrpe_check_var (
  String $critical = '10%',
  String $warning = '20%',
) {
    sunet::nagios::nrpe_command {'check_var':
      command_line => "/usr/lib/nagios/plugins/check_disk -w ${warning} -c ${critical} -p /var"
    }
}
