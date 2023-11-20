# Check process
define sunet::nagios::nrpe_check_process (
  $display_name = undef
) {

  include sunet::nagios::nrpe_check_process_command

  $process_display_name = $alias ? {
    undef   => $name,
    default => $alias
  }
  sunet::nagios::nrpe_command {"check_process_${name}":
    command_line => "/usr/lib/nagios/plugins/check_process -C PCPU -p ${name} -N ${process_display_name}"
  }
}
