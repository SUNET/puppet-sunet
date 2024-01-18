# Check entropy
define sunet::nagios::nrpe_check_entropy (
  Integer $warning = 256,
) {
    sunet::nagios::nrpe_command { 'check_entropy':
      command_line => "/usr/lib/nagios/plugins/check_entropy -w ${warning}",
    }
}
