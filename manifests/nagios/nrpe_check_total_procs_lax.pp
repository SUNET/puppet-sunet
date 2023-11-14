# Check total procs lax
define sunet::nagios::nrpe_check_total_procs_lax (
  Integer $critical = 200,
  Integer $warning = 150,
) {
  if is_hash($facts) and has_key($facts, 'cosmos') and ('frontend_server' in $facts['cosmos']['host_roles']) {
    # There are more processes than normal on frontend hosts
    $_procw = $warning + 350
    $_procc = $critical + 350
  } else {
    $_procw = $warning
    $_procc = $critical
  }
  sunet::nagios::nrpe_command {'check_total_procs_lax':
    command_line => "/usr/lib/nagios/plugins/check_procs -k -w ${_procw} -c ${_procc}"
  }
}
