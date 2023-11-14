# Check boot inodes
define sunet::nagios::nrpe_check_boot_inodes (
  Integer $warning = 15,
  Integer $critical = 5,
) {
    sunet::nagios::nrpe_command {'check_boot_inodes':
      command_line => "/usr/lib/nagios/plugins/check_inodes -w ${warning} -c ${critical} -p /boot",
    }
}
