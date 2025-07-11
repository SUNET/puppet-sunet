# Check total procs lax
define sunet::nagios::nrpe_check_total_procs_lax (
  Integer $critical = 200,
  Integer $warning = 150,
) {
    $_procw = lookup('check_total_procs_warning', undef, undef, $warning)
    $_procc = lookup('check_total_procs_critical', undef, undef, $critical)
  sunet::nagios::nrpe_command {'check_total_procs_lax':
    command_line => "/usr/lib/nagios/plugins/check_procs -k -w ${_procw} -c ${_procc}"
  }
}
