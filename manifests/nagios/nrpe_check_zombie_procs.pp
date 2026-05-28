# Check zombies
define sunet::nagios::nrpe_check_zombie_procs (
  Integer $critical = 5,
  Integer $warning = 10,
) {

  $_zprocw = lookup('check_zombie_procs_warning', undef, undef, $warning)
  $_zprocc = lookup('check_zombie_procs_critical', undef, undef, $critical)

  sunet::nagios::nrpe_command {'check_zombie_procs':
    command_line => "/usr/lib/nagios/plugins/check_procs -w ${_zprocw} -c ${_zprocc} -s Z"
  }
}
