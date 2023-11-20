# Check process
define sunet::nagios::nrpe_check_process (
  $display_name = undef
) {

  include sunet::nagios::nrpe_check_process_command

  $process_display_name = $display_name ? {
    undef   => $name,
    default => $display_name
  }
  sunet::nagios::nrpe_command {"check_process_${name}":
    command_line => "/usr/lib/nagios/plugins/check_process -C PCPU -p ${name} -N ${process_display_name}"
  }
}
