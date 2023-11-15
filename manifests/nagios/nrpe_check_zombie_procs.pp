# Check zombies
define sunet::nagios::nrpe_check_zombie_procs (
  Integer $critical = 5,
  Integer $warning = 10,
) {

  sunet::nagios::nrpe_command {'check_zombie_procs':
    command_line => "/usr/lib/nagios/plugins/check_procs -w ${warning} -c ${critical} -s Z"
  }
}
