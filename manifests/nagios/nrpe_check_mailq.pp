# Check mailq
define sunet::nagios::nrpe_check_mailq (
  Integer $critical = 100,
  Integer $warning = 20,
) {
  sunet::nagios::nrpe_command {'check_mailq':
    command_line => "/usr/lib/nagios/plugins/check_mailq -w ${warning} -c ${critical}"
  }
}
