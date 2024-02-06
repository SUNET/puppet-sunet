# Check / inodes
define sunet::nagios::nrpe_check_root_inodes (
  Integer $warning = 15,
  Integer $critical = 5,
) {
    sunet::nagios::nrpe_command {'check_root_inodes':
      command_line => "/usr/lib/nagios/plugins/check_inodes -w ${warning} -c ${critical} -p /",
    }
}
