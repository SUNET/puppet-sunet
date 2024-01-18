# Check users
define sunet::nagios::nrpe_check_users (
  Integer $critical = 5,
  Integer $warning = 10,
) {
  sunet::nagios::nrpe_command {'check_users':
    command_line => "/usr/lib/nagios/plugins/check_users -w ${warning} -c ${critical}"
  }
}
