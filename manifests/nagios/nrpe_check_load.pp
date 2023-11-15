# Check load
define sunet::nagios::nrpe_check_load (
  String $critical = '15,10,5',
  String $warning = '15,10,5',
) {

  sunet::nagios::nrpe_command {'check_load':
    command_line => "/usr/lib/nagios/plugins/check_load -w ${warning} -c ${critical}"
  }

}
